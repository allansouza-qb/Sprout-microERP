defmodule SproutErp.Inventory do
  @moduledoc "Units moving through the Sprout refurbishment pipeline."

  import Ecto.Query
  alias Ecto.Multi
  alias SproutErp.Repo
  alias SproutErp.Inventory.{Unit, WorkItem, Event, Sale}

  @topic "inventory"

  def subscribe, do: Phoenix.PubSub.subscribe(SproutErp.PubSub, @topic)

  @doc "Tells every subscriber (the open screens, through the channel) that inventory changed."
  def broadcast_change, do: Phoenix.PubSub.broadcast(SproutErp.PubSub, @topic, :inventory_changed)

  defp broadcast(result), do: tap(result, fn _ -> broadcast_change() end)

  ## Queries

  def list_units(opts \\ []) do
    Unit
    |> filter(:status, opts[:status])
    |> filter(:category, opts[:category])
    |> filter(:search, opts[:search])
    |> order_by([u], desc: u.updated_at, desc: u.id)
    |> preload([:product, lot: :supplier])
    |> Repo.all()
  end

  defp filter(q, _key, nil), do: q
  defp filter(q, _key, ""), do: q
  defp filter(q, :status, s), do: where(q, [u], u.status == ^s)

  defp filter(q, :category, c),
    do:
      join(q, :inner, [u], p in assoc(u, :product), as: :cat_p)
      |> where([cat_p: p], p.category == ^c)

  defp filter(q, :search, term) do
    like = "%" <> String.replace(term, ~r/[\\%_]/, "\\\\\\0") <> "%"

    q
    |> join(:inner, [u], p in assoc(u, :product), as: :search_p)
    |> where(
      [u, search_p: p],
      ilike(u.sku, ^like) or ilike(p.name, ^like) or ilike(p.brand, ^like) or
        ilike(u.serial, ^like)
    )
  end

  def list_workshop do
    Unit
    |> where([u], u.status in ~w(received inspecting refurbishing ready))
    |> order_by([u], asc: u.received_on, asc: u.id)
    |> preload([:product, :work_items, lot: :supplier])
    |> Repo.all()
    |> Enum.group_by(& &1.status)
  end

  @doc "Sold units whose sale date falls in `range` (\"30\", \"90\", \"all\"), newest first."
  def list_sold_units(range) do
    Unit
    |> where([u], u.status == "sold")
    |> since(range)
    |> order_by([u], desc: u.sold_on, desc: u.id)
    |> preload([:product, lot: :supplier])
    |> Repo.all()
  end

  @doc "Active Amazon offers, oldest first."
  def list_listed_units do
    Unit
    |> where([u], u.status == "listed")
    |> order_by([u], asc: u.listed_on, asc: u.id)
    |> preload([:product, lot: :supplier])
    |> Repo.all()
  end

  def get_unit!(id) do
    Unit
    |> Repo.get!(id)
    |> Repo.preload([:product, :work_items, :sales, :events, lot: :supplier])
  end

  @doc "Ledger rows with the given statuses whose sale date falls in `range` (\"30\", \"90\", \"all\")."
  def list_sales(range, statuses \\ Sale.statuses()) do
    Sale
    |> where([s], s.status in ^statuses)
    |> since(range)
    |> order_by([s], desc: s.sold_on, desc: s.id)
    |> preload(unit: [:product, lot: :supplier])
    |> Repo.all()
  end

  # Works for both sales and units: each has a `sold_on` date.
  defp since(q, "all"), do: q

  defp since(q, days) when days in ["30", "90"] do
    from_date = Date.add(SproutErp.Clock.today(), -(String.to_integer(days) - 1))
    where(q, [row], row.sold_on >= ^from_date)
  end

  def recent_events(limit \\ 8) do
    Event
    |> order_by(desc: :occurred_at, desc: :id)
    |> limit(^limit)
    |> preload(unit: :product)
    |> Repo.all()
  end

  def count_by_status do
    Unit
    |> group_by(:status)
    |> select([u], {u.status, count(u.id)})
    |> Repo.all()
    |> Map.new()
  end

  ## Pipeline transitions

  def suggested_price_cents(%Unit{grade: g, product: %{msrp_cents: msrp}}) do
    (msrp * Unit.grade_price_factor(g))
    |> round()
    |> then(&(div(&1, 100) * 100 - 1))
  end

  # Every stage change below is guarded twice:
  #   * the clause matches only the expected current status — a unit that
  #     already moved on returns {:error, :stale} instead of crashing;
  #   * the update uses optimistic locking on `lock_version`, so a caller
  #     holding an outdated copy (second tab, double click) also gets
  #     {:error, :stale} and nothing is written.

  def start_inspection(unit, opts \\ [])

  def start_inspection(%Unit{status: "received"} = unit, opts),
    do: transition(unit, %{status: "inspecting"}, "inspection", "Inspection started", opts)

  def start_inspection(%Unit{}, _opts), do: {:error, :stale}

  def assign_grade(unit, grade, opts \\ [])

  def assign_grade(%Unit{status: "inspecting"} = unit, grade, opts)
      when grade in ["premium", "excellent", "good", "acceptable"] do
    transition(
      unit,
      %{status: "refurbishing", grade: grade},
      "graded",
      "Graded #{Unit.grade_label(grade)} · sent to the bench",
      opts
    )
  end

  def assign_grade(%Unit{status: "inspecting"}, _grade, _opts), do: {:error, "Unknown grade"}
  def assign_grade(%Unit{}, _grade, _opts), do: {:error, :stale}

  def mark_ready(unit, opts \\ [])

  def mark_ready(%Unit{status: "refurbishing"} = unit, opts) do
    unit = Repo.preload(unit, :work_items, force: true)

    if Enum.any?(unit.work_items, &(!&1.done)) do
      {:error, "Finish all bench tasks before passing QC."}
    else
      transition(
        unit,
        %{status: "ready", bin: unit.bin || random_bin()},
        "qc",
        "Passed QC · ready to list",
        opts
      )
    end
  end

  def mark_ready(%Unit{}, _opts), do: {:error, :stale}

  def list_on_amazon(unit, price_cents \\ nil, opts \\ [])

  def list_on_amazon(%Unit{status: "ready"} = unit, price_cents, opts)
      when is_nil(price_cents) or is_integer(price_cents) do
    unit = Repo.preload(unit, :product)
    price = price_cents || suggested_price_cents(unit)

    transition(
      unit,
      %{status: "listed", list_price_cents: price, listed_on: SproutErp.Clock.today()},
      "listed",
      "Listed on Amazon Renewed at #{SproutErp.Money.format(price)}",
      opts
    )
  end

  def list_on_amazon(%Unit{}, _price_cents, _opts), do: {:error, :stale}

  def record_sale(unit, price_cents \\ nil, opts \\ [])

  def record_sale(%Unit{status: "listed"} = unit, price_cents, opts)
      when is_nil(price_cents) or (is_integer(price_cents) and price_cents > 0) do
    unit = Repo.preload(unit, :product)
    price = price_cents || unit.list_price_cents

    sale = %{
      sale_price_cents: price,
      fees_cents: Unit.estimated_fees_cents(unit, price),
      fees_estimated: true,
      sold_on: SproutErp.Clock.today(),
      order_ref: random_order_ref()
    }

    ledger = fn multi ->
      Multi.insert(multi, :sale, fn %{unit: u} ->
        %Sale{
          unit_id: u.id,
          order_ref: sale.order_ref,
          price_cents: price,
          fees_cents: sale.fees_cents,
          fees_estimated: true,
          sold_on: sale.sold_on,
          status: "completed"
        }
      end)
    end

    transition(
      unit,
      Map.put(sale, :status, "sold"),
      "sold",
      "Sold on Amazon for #{SproutErp.Money.format(price)}",
      Keyword.put(opts, :extra, ledger)
    )
  end

  def record_sale(%Unit{status: "listed"}, _price, _opts),
    do: {:error, "Enter a valid sale price"}

  def record_sale(%Unit{}, _price_cents, _opts), do: {:error, :stale}

  @doc """
  Buyer cancelled before shipment: the sale stays in the ledger as
  `cancelled` and the unit goes back to its Amazon listing.
  """
  def cancel_sale(unit, reason \\ nil, opts \\ [])

  def cancel_sale(%Unit{status: "sold"} = unit, reason, opts) do
    close_sale(
      unit,
      "cancelled",
      reason,
      %{status: "listed"},
      "sale_cancelled",
      fn sale -> "Order #{sale.order_ref} cancelled · back on Amazon" end,
      opts
    )
  end

  def cancel_sale(%Unit{}, _reason, _opts), do: {:error, :stale}

  @doc """
  Customer return: the sale stays in the ledger as `returned` and the unit
  goes back to receiving for a new inspection (listing data is cleared; bench
  costs already spent stay on the unit).
  """
  def return_sale(unit, reason \\ nil, opts \\ [])

  def return_sale(%Unit{status: "sold"} = unit, reason, opts) do
    close_sale(
      unit,
      "returned",
      reason,
      %{status: "received", list_price_cents: nil, listed_on: nil, bin: nil},
      "sale_returned",
      fn sale -> "Order #{sale.order_ref} returned · back to receiving for re-inspection" end,
      opts
    )
  end

  def return_sale(%Unit{}, _reason, _opts), do: {:error, :stale}

  defp close_sale(unit, status, reason, unit_attrs, kind, message_fun, opts) do
    case current_sale(unit) do
      # the sale was already cancelled/returned from another screen
      nil ->
        {:error, :stale}

      sale ->
        reason = if is_binary(reason) and String.trim(reason) != "", do: String.trim(reason)

        attrs =
          Map.merge(unit_attrs, %{
            sale_price_cents: nil,
            fees_cents: nil,
            fees_estimated: true,
            sold_on: nil,
            order_ref: nil
          })

        message = message_fun.(sale) <> if(reason, do: " — #{reason}", else: "")

        close = fn multi ->
          Multi.update(
            multi,
            :sale,
            Ecto.Changeset.change(sale,
              status: status,
              closed_on: SproutErp.Clock.today(),
              close_reason: reason
            )
          )
        end

        transition(unit, attrs, kind, message, Keyword.put(opts, :extra, close))
    end
  end

  defp current_sale(%Unit{id: id}) do
    Sale
    |> where([s], s.unit_id == ^id and s.status == "completed")
    |> order_by([s], desc: s.id)
    |> limit(1)
    |> Repo.one()
  end

  def update_list_price(unit, price_cents, opts \\ [])

  def update_list_price(%Unit{status: "listed"} = unit, price_cents, opts)
      when is_integer(price_cents) and price_cents > 0 do
    transition(
      unit,
      %{list_price_cents: price_cents},
      "repriced",
      "Repriced to #{SproutErp.Money.format(price_cents)}",
      opts
    )
  end

  def update_list_price(%Unit{status: "listed"}, _, _opts), do: {:error, "Invalid price"}
  def update_list_price(%Unit{}, _, _opts), do: {:error, :stale}

  # opts: `extra:` adds steps to the same transaction (e.g. the sales ledger row).
  defp transition(unit, attrs, kind, message, opts) do
    extra = Keyword.get(opts, :extra, & &1)

    changeset =
      unit
      |> Unit.changeset(attrs)
      |> Ecto.Changeset.optimistic_lock(:lock_version)

    Multi.new()
    |> Multi.update(:unit, changeset, stale_error_field: :lock_version)
    |> extra.()
    |> Multi.insert(:event, fn %{unit: u} -> event(u.id, kind, message) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{unit: u}} ->
        broadcast({:ok, u})

      {:error, :unit, %Ecto.Changeset{errors: errors} = changeset, _} ->
        if Keyword.has_key?(errors, :lock_version),
          do: {:error, :stale},
          else: {:error, changeset}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc "Builds a history event. `at:` sets the instant (defaults to now)."
  def event(unit_id, kind, message, opts \\ []) do
    at = Keyword.get(opts, :at, DateTime.utc_now())

    %Event{
      unit_id: unit_id,
      kind: kind,
      message: message,
      occurred_at: DateTime.truncate(at, :second)
    }
  end

  ## Bench work

  # Bench tasks feed the unit's cost, so they can only change while the unit
  # is still in the workshop (before final QC).
  @bench_stages ~w(received inspecting refurbishing)
  @bench_closed "Bench tasks can only change before final QC."

  defp bench_open?(unit_id) do
    Repo.one(from u in Unit, where: u.id == ^unit_id, select: u.status) in @bench_stages
  end

  def add_work_item(%Unit{} = unit, attrs) do
    if bench_open?(unit.id) do
      Multi.new()
      |> Multi.insert(:item, WorkItem.changeset(%WorkItem{}, Map.put(attrs, "unit_id", unit.id)))
      |> Multi.run(:cost, fn _, _ -> recompute_refurb_cost(unit.id) end)
      |> Multi.insert(:event, fn %{item: i} ->
        event(unit.id, "bench", "Bench task added · #{i.description}")
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{item: item}} -> broadcast({:ok, item})
        {:error, :item, changeset, _} -> {:error, changeset}
      end
    else
      {:error, @bench_closed}
    end
  end

  def toggle_work_item(id) do
    item = Repo.get!(WorkItem, id)
    verb = if item.done, do: "reopened", else: "completed"

    change_bench(item, "Bench task #{verb} · #{item.description}", fn multi ->
      Multi.update(multi, :item, Ecto.Changeset.change(item, done: !item.done))
    end)
  end

  def delete_work_item(id) do
    item = Repo.get!(WorkItem, id)

    change_bench(item, "Bench task removed · #{item.description}", fn multi ->
      Multi.delete(multi, :item, item)
    end)
  end

  defp change_bench(%WorkItem{} = item, message, step) do
    if bench_open?(item.unit_id) do
      Multi.new()
      |> step.()
      |> Multi.run(:cost, fn _, _ -> recompute_refurb_cost(item.unit_id) end)
      |> Multi.insert(:event, fn _ -> event(item.unit_id, "bench", message) end)
      |> Repo.transaction()
      |> case do
        {:ok, %{item: item}} -> broadcast({:ok, item})
        {:error, _step, reason, _} -> {:error, reason}
      end
    else
      {:error, @bench_closed}
    end
  end

  @doc """
  Bench cost split: `completed` is what the unit has actually consumed and is
  the only part counted in its cost; `pending` is planned work not done yet.
  """
  def bench_costs(work_items) do
    {done, pending} = Enum.split_with(work_items, & &1.done)
    cost = fn items -> items |> Enum.map(&WorkItem.cost_cents/1) |> Enum.sum() end
    %{completed: cost.(done), pending: cost.(pending)}
  end

  # The unit's refurbishment cost counts completed tasks only.
  defp recompute_refurb_cost(unit_id) do
    %{completed: total} = WorkItem |> where(unit_id: ^unit_id) |> Repo.all() |> bench_costs()

    {n, _} =
      Unit
      |> where(id: ^unit_id)
      |> Repo.update_all(
        set: [refurb_cost_cents: total, updated_at: DateTime.utc_now(:second)],
        inc: [lock_version: 1]
      )

    {:ok, n}
  end

  ## Helpers

  @doc """
  Applies the `lock_version` the client rendered (sent back as a param), so the
  optimistic lock rejects actions taken on an outdated screen.
  """
  def with_seen_version(%Unit{} = unit, version) when is_binary(version) do
    case Integer.parse(version) do
      {v, ""} -> %{unit | lock_version: v}
      _ -> unit
    end
  end

  def with_seen_version(%Unit{} = unit, _), do: unit

  @sku_sequence "unit_sku"

  @doc """
  Reserves `count` consecutive SKU numbers from the `sequences` table and
  returns the first one. A single atomic `UPDATE … RETURNING`; call it inside
  the transaction that creates the units so a failed receipt rolls it back.
  SKUs no longer depend on row ids.
  """
  def reserve_sku_numbers(count) when is_integer(count) and count > 0 do
    case from(s in "sequences", where: s.name == ^@sku_sequence, select: s.value)
         |> Repo.update_all(inc: [value: count]) do
      {1, [last]} -> last - count + 1
      {0, _} -> raise "SKU sequence #{inspect(@sku_sequence)} is missing — run the migrations"
    end
  end

  @doc "Resets the SKU sequence (used by the demo seeds after wiping units)."
  def reset_sku_sequence(value \\ 10_000) do
    from(s in "sequences", where: s.name == ^@sku_sequence)
    |> Repo.update_all(set: [value: value])
  end

  def random_bin do
    "#{Enum.random(~w(A B C D))}-#{Enum.random(1..12) |> Integer.to_string() |> String.pad_leading(2, "0")}-#{Enum.random(1..6)}"
  end

  def random_order_ref do
    "11#{Enum.random(1..9)}-#{:rand.uniform(9_999_999) |> pad(7)}-#{:rand.uniform(9_999_999) |> pad(7)}"
  end

  defp pad(n, w), do: n |> Integer.to_string() |> String.pad_leading(w, "0")
end
