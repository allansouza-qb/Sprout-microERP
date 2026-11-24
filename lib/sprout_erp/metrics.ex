defmodule SproutErp.Metrics do
  @moduledoc """
  Read-side aggregations that power the dashboard and reports.

  The dashboard numbers are computed by PostgreSQL (sums, counts and averages
  grouped in the database); only the handful of rows a screen actually lists
  are loaded as structs.
  """

  import Ecto.Query

  alias SproutErp.{Clock, Inventory, Repo}
  alias SproutErp.Inventory.Unit

  # Realized profit of a sold unit: sale price − fees − (acquisition + bench).
  # Same rule as `Unit.profit_cents/1`, written for the database.
  defmacrop profit(u) do
    quote do
      unquote(u).sale_price_cents - coalesce(unquote(u).fees_cents, 0) -
        unquote(u).acquisition_cost_cents - unquote(u).refurb_cost_cents
    end
  end

  ## Dashboard

  def dashboard(today \\ Clock.today()) do
    last30 = sold_totals(Date.add(today, -29), today)
    prev30 = sold_totals(Date.add(today, -59), Date.add(today, -30))
    stock = stock_totals()

    %{
      revenue: last30.revenue,
      revenue_prev: prev30.revenue,
      profit: last30.profit,
      profit_prev: prev30.profit,
      units_sold: last30.units,
      units_sold_prev: prev30.units,
      inventory_cost: stock.cost,
      inventory_units: stock.units,
      listed_value: stock.listed_value,
      avg_days_to_sell: last30.avg_days || 0.0,
      avg_days_to_sell_prev: prev30.avg_days || 0.0,
      pipeline: pipeline(),
      weekly: weekly(today, 12),
      categories: categories(),
      aging: aging(today)
    }
  end

  # Revenue, profit, units and average days from receipt to sale of the units
  # sold between two dates (inclusive).
  defp sold_totals(from, to) do
    Repo.one(
      from u in Unit,
        where: u.status == "sold" and u.sold_on >= ^from and u.sold_on <= ^to,
        select: %{
          revenue: coalesce(sum(u.sale_price_cents), 0),
          profit: coalesce(sum(profit(u)), 0),
          units: count(u.id),
          avg_days: type(avg(fragment("coalesce(? - ?, 0)", u.sold_on, u.received_on)), :float)
        }
    )
  end

  # Everything not sold yet: how many units, what they cost so far, and the
  # asking price of the ones on Amazon.
  defp stock_totals do
    Repo.one(
      from u in Unit,
        where: u.status != "sold",
        select: %{
          units: count(u.id),
          cost: coalesce(sum(u.acquisition_cost_cents + u.refurb_cost_cents), 0),
          listed_value: coalesce(filter(sum(u.list_price_cents), u.status == "listed"), 0)
        }
    )
  end

  @doc "Units per stage, in pipeline order (stages with no units count 0)."
  def pipeline do
    counts = Inventory.count_by_status()
    Enum.map(Unit.statuses(), &{&1, Map.get(counts, &1, 0)})
  end

  @doc "Revenue, profit and units sold per week (Monday to Sunday) for the last `weeks` weeks."
  def weekly(today, weeks) do
    monday = Date.beginning_of_week(today)
    first = Date.add(monday, -7 * (weeks - 1))

    by_week =
      from(u in Unit,
        where: u.status == "sold" and u.sold_on >= ^first and u.sold_on <= ^Date.add(monday, 6),
        group_by: selected_as(:week),
        select: %{
          week: selected_as(fragment("date_trunc('week', ?::timestamp)::date", u.sold_on), :week),
          revenue: coalesce(sum(u.sale_price_cents), 0),
          profit: coalesce(sum(profit(u)), 0),
          units: count(u.id)
        }
      )
      |> Repo.all()
      |> Map.new(&{&1.week, &1})

    # weeks without sales still appear in the chart, as zero
    for i <- (weeks - 1)..0//-1 do
      start = Date.add(monday, -7 * i)
      row = Map.get(by_week, start, %{revenue: 0, profit: 0, units: 0})
      %{start: start, revenue: row.revenue, profit: row.profit, units: row.units}
    end
  end

  @doc """
  The weekly revenue chart: the weeks plus a rounded scale (`top` and evenly
  spaced `ticks`, highest first) so the front end only draws.
  """
  def revenue_chart(weekly) do
    max = weekly |> Enum.map(& &1.revenue) |> Enum.max(fn -> 0 end)
    step = nice_step(max / 4)
    top = step * max(1, ceil(max / step))
    ticks = for i <- round(top / step)..0//-1, do: i * step

    %{weeks: weekly, top: top, ticks: ticks}
  end

  # 1, 2, 2.5, 5 or 10 times a power of ten (in cents), never below $100.
  defp nice_step(value) when value <= 0, do: 100_00

  defp nice_step(value) do
    magnitude = :math.pow(10, Float.floor(:math.log10(value)))
    multiple = Enum.find([1, 2, 2.5, 5, 10], &(&1 * magnitude >= value))
    max(round(multiple * magnitude), 100_00)
  end

  @doc "Units sold, revenue, profit and margin per product category, best profit first."
  def categories do
    from(u in Unit,
      join: p in assoc(u, :product),
      where: u.status == "sold",
      group_by: p.category,
      select: %{
        category: p.category,
        units: count(u.id),
        revenue: coalesce(sum(u.sale_price_cents), 0),
        profit: coalesce(sum(profit(u)), 0)
      }
    )
    |> Repo.all()
    |> Enum.map(&Map.put(&1, :margin, ratio(&1.profit, &1.revenue) || 0))
    |> Enum.sort_by(&{-&1.profit, &1.category})
  end

  @bench_stages ~w(received inspecting refurbishing)
  @bench_days 10
  @listed_days 21

  @doc """
  The units stuck the longest (six by default): in the workshop for more than
  #{@bench_days} days since receipt, or on Amazon for more than #{@listed_days} days.
  Returns `{unit, days}`.
  """
  def aging(today, limit \\ 6) do
    bench_before = Date.add(today, -@bench_days)
    listed_before = Date.add(today, -@listed_days)

    from(u in Unit,
      where:
        (u.status == "listed" and u.listed_on < ^listed_before) or
          (u.status in @bench_stages and u.received_on < ^bench_before),
      select:
        {u,
         selected_as(
           fragment(
             "? - (case when ? = 'listed' then ? else ? end)",
             type(^today, :date),
             u.status,
             u.listed_on,
             u.received_on
           ),
           :days
         )},
      order_by: [desc: selected_as(:days), asc: u.id],
      limit: ^limit,
      preload: [:product, lot: :supplier]
    )
    |> Repo.all()
  end

  ## Sales and listings screens

  @doc """
  The sales screen for a period (`"30"`, `"90"` or `"all"`): completed sales
  newest first, the cancelled and returned orders kept in the ledger, and the
  totals of what is shown. `fees_estimated` is true while any fee in the
  period is still Sprout's estimate.
  """
  def sales(range) do
    sold = Inventory.list_sold_units(range)

    revenue = sum(sold, & &1.sale_price_cents)
    fees = sum(sold, & &1.fees_cents)
    cost = sum(sold, &Unit.total_cost_cents/1)
    profit = revenue - fees - cost

    %{
      sales: sold,
      closed: Inventory.list_sales(range, ~w(cancelled returned)),
      totals: %{
        orders: length(sold),
        revenue: revenue,
        fees: fees,
        fees_share: ratio(fees, revenue),
        cost: cost,
        profit: profit,
        margin: ratio(profit, revenue),
        fees_estimated: sold == [] or Enum.any?(sold, & &1.fees_estimated)
      }
    }
  end

  @doc "Active Amazon offers, oldest first, with the totals shown above the table."
  def listings(today \\ Clock.today()) do
    units = Inventory.list_listed_units()
    days = sum(units, &Date.diff(today, &1.listed_on))

    %{
      units: units,
      summary: %{
        count: length(units),
        value: sum(units, & &1.list_price_cents),
        projected_profit: sum(units, &Unit.profit_cents/1),
        avg_days: if(units == [], do: 0, else: days / length(units))
      }
    }
  end

  ## Helpers

  defp sum(list, fun), do: list |> Enum.map(fun) |> Enum.reject(&is_nil/1) |> Enum.sum()

  @doc "`value / base`, or `nil` when there is no base to compare with."
  def ratio(nil, _base), do: nil
  def ratio(_value, nil), do: nil
  def ratio(_value, 0), do: nil
  def ratio(value, base), do: value / base

  def delta(_, 0), do: nil
  def delta(_, prev) when prev == 0.0, do: nil
  def delta(cur, prev), do: (cur - prev) / abs(prev)
end
