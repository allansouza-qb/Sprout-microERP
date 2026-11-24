defmodule SproutErp.Purchasing do
  @moduledoc "Sourcing: suppliers and the purchase lots Sprout buys from them."

  import Ecto.Query
  alias Ecto.Multi
  alias SproutErp.Repo
  alias SproutErp.Purchasing.{Supplier, Lot}
  alias SproutErp.Catalog.Product
  alias SproutErp.Inventory
  alias SproutErp.Inventory.Unit

  def list_suppliers, do: Supplier |> order_by(:name) |> Repo.all()
  def list_products, do: Product |> order_by([:category, :brand, :name]) |> Repo.all()

  def list_lots do
    Lot
    |> order_by(desc: :purchased_on, desc: :id)
    |> preload([:supplier, units: [:product, :work_items]])
    |> Repo.all()
  end

  def get_lot!(id) do
    Lot
    |> Repo.get!(id)
    |> Repo.preload([
      :supplier,
      units: from(u in Unit, order_by: u.sku, preload: [:product, :work_items])
    ])
  end

  @doc """
  Aggregated economics for one lot, with realized and projected kept apart.

    * realized — what already happened: `invested` = lot cost + completed bench
      work; `realized_profit`/`realized_roi` use net revenue of sold units only
      and are `nil` until the lot's first sale (nothing realized yet).
    * projected — `projected_cost` adds the pending bench tasks to `invested`;
      `projected_net` adds the expected proceeds of unsold units (list price, or
      the grade-based suggested price) after estimated fees. Units not inspected
      yet have no bench tasks, so their future bench cost is not included.
  """
  def lot_stats(%Lot{units: units} = lot) do
    sold = Enum.filter(units, &(&1.status == "sold"))
    revenue = sold |> Enum.map(& &1.sale_price_cents) |> Enum.sum()
    net = sold |> Enum.map(&(&1.sale_price_cents - &1.fees_cents)) |> Enum.sum()

    bench_completed = units |> Enum.map(& &1.refurb_cost_cents) |> Enum.sum()
    %{pending: bench_pending} = units |> Enum.flat_map(& &1.work_items) |> Inventory.bench_costs()

    invested = lot.total_cost_cents + bench_completed
    projected_cost = invested + bench_pending
    projected_net = units |> Enum.map(&expected_net/1) |> Enum.sum()
    realized_profit = net - invested
    projected_profit = projected_net - projected_cost

    %{
      units: length(units),
      sold: length(sold),
      sell_through: if(units == [], do: 0, else: length(sold) / length(units)),
      revenue: revenue,
      net: net,
      bench_completed: bench_completed,
      bench_pending: bench_pending,
      invested: invested,
      realized_profit: if(sold == [], do: nil, else: realized_profit),
      realized_roi: if(sold == [], do: nil, else: ratio(realized_profit, invested)),
      projected_cost: projected_cost,
      projected_net: projected_net,
      projected_profit: projected_profit,
      projected_roi: ratio(projected_profit, projected_cost)
    }
  end

  defp ratio(_value, base) when base <= 0, do: 0.0
  defp ratio(value, base), do: value / base

  # Expected net proceeds per unit: realized if sold, else list price or
  # the grade-based suggested price (ungraded units assume "good").
  defp expected_net(%Unit{status: "sold"} = u), do: u.sale_price_cents - u.fees_cents

  defp expected_net(%Unit{} = u) do
    price =
      u.list_price_cents ||
        Inventory.suggested_price_cents(%{u | grade: u.grade || "good"})

    price - Unit.estimated_fees_cents(u, price)
  end

  @doc """
  Supplier scorecard built only from recorded data — no subjective rating.

    * `sell_through` — share of the supplier's units already sold
    * `avg_margin` — realized profit ÷ revenue over the supplier's sold units
      (revenue-weighted); `nil` until something sells

  Takes the lots as loaded by `list_lots/0`, so a caller that already has them
  does not query twice.
  """
  def supplier_stats(lots \\ list_lots()) do
    lots
    |> Enum.group_by(& &1.supplier)
    |> Enum.map(fn {supplier, lots} ->
      stats = Enum.map(lots, &lot_stats/1)
      units = Enum.flat_map(lots, & &1.units)
      sold = Enum.filter(units, &(&1.status == "sold"))
      sold_revenue = sold |> Enum.map(& &1.sale_price_cents) |> Enum.sum()
      sold_profit = sold |> Enum.map(&Unit.profit_cents/1) |> Enum.sum()

      %{
        supplier: supplier,
        lots: length(lots),
        units: length(units),
        sold: length(sold),
        sell_through: if(units == [], do: nil, else: length(sold) / length(units)),
        avg_margin: if(sold_revenue > 0, do: sold_profit / sold_revenue, else: nil),
        spend: lots |> Enum.map(& &1.total_cost_cents) |> Enum.sum(),
        revenue: stats |> Enum.map(& &1.revenue) |> Enum.sum()
      }
    end)
    |> Enum.sort_by(& &1.spend, :desc)
  end

  def next_reference(date \\ SproutErp.Clock.today()) do
    prefix = "LOT-" <> Calendar.strftime(date, "%y%m") <> "-"
    n = Repo.one(from l in Lot, where: like(l.reference, ^(prefix <> "%")), select: count(l.id))
    prefix <> String.pad_leading(Integer.to_string(n + 1), 2, "0")
  end

  @doc """
  Receives a purchase lot: creates the lot and one unit per item,
  allocating the lot cost across units proportionally to MSRP.

  `lines` is a list of `{product_id, quantity}`.
  """
  def receive_lot(attrs, lines) do
    products = Map.new(list_products(), &{&1.id, &1})

    items =
      for {pid, qty} <- lines, qty > 0, p = products[pid], p != nil, _ <- 1..qty, do: p

    changeset = Lot.changeset(%Lot{}, attrs)

    cond do
      items == [] ->
        {:error,
         Ecto.Changeset.add_error(changeset, :lines, "add at least one item")
         |> Map.put(:action, :insert)}

      not changeset.valid? ->
        {:error, Map.put(changeset, :action, :insert)}

      true ->
        do_receive(changeset, items)
    end
  end

  defp do_receive(changeset, items) do
    Multi.new()
    |> Multi.insert(:lot, changeset)
    |> Multi.run(:units, fn repo, %{lot: lot} ->
      costs = allocate_cents(lot.total_cost_cents, Enum.map(items, & &1.msrp_cents))
      base = Inventory.reserve_sku_numbers(length(items))

      units =
        items
        |> Enum.zip(costs)
        |> Enum.with_index()
        |> Enum.map(fn {{p, cost}, i} ->
          unit =
            %Unit{}
            |> Unit.changeset(%{
              sku: "SPR-#{base + i}",
              serial: serial(),
              product_id: p.id,
              lot_id: lot.id,
              status: "received",
              acquisition_cost_cents: cost,
              received_on: lot.purchased_on
            })
            |> repo.insert!()

          repo.insert!(Inventory.event(unit.id, "received", "Received from #{lot.reference}"))

          unit
        end)

      {:ok, units}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{lot: lot}} ->
        Inventory.broadcast_change()
        {:ok, lot}

      {:error, :lot, cs, _} ->
        {:error, cs}
    end
  end

  @doc """
  Splits `total_cents` across `weights` in whole cents so the parts add up
  exactly to the total (largest-remainder method, integer math only).

  Each part is first rounded down; the leftover cents then go one by one to
  the parts with the largest remainder, ties going to the earlier position.
  Zero or negative total weight falls back to an equal split.

      iex> SproutErp.Purchasing.allocate_cents(10_000, [1, 1, 1])
      [3334, 3333, 3333]
  """
  def allocate_cents(total_cents, []) when is_integer(total_cents), do: []

  def allocate_cents(total_cents, weights) when is_integer(total_cents) and total_cents >= 0 do
    weights =
      if Enum.sum(weights) > 0, do: weights, else: List.duplicate(1, length(weights))

    sum = Enum.sum(weights)

    parts =
      weights
      |> Enum.with_index()
      |> Enum.map(fn {w, i} -> {i, div(total_cents * w, sum), rem(total_cents * w, sum)} end)

    leftover = total_cents - (parts |> Enum.map(&elem(&1, 1)) |> Enum.sum())

    extra =
      parts
      |> Enum.sort_by(fn {i, _floor, r} -> {-r, i} end)
      |> Enum.take(leftover)
      |> MapSet.new(&elem(&1, 0))

    Enum.map(parts, fn {i, floor, _} ->
      if MapSet.member?(extra, i), do: floor + 1, else: floor
    end)
  end

  def serial do
    for(_ <- 1..10, into: "", do: <<Enum.random(~c"ABCDEFGHJKLMNPQRSTUVWXYZ0123456789")>>)
  end
end
