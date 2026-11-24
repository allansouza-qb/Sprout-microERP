defmodule SproutErpWeb.API.DashboardController do
  use SproutErpWeb, :controller

  alias SproutErp.{Clock, Inventory, Metrics}
  alias SproutErp.Catalog.Product
  alias SproutErp.Inventory.Unit
  alias SproutErpWeb.API.Render

  def show(conn, _params) do
    m = Metrics.dashboard()

    json(conn, %{
      data: %{
        greeting: Clock.greeting(),
        today: Clock.today(),
        kpis: %{
          revenue_cents: m.revenue,
          revenue_delta: Metrics.delta(m.revenue, m.revenue_prev),
          profit_cents: m.profit,
          profit_delta: Metrics.delta(m.profit, m.profit_prev),
          margin: Render.ratio(m.profit, m.revenue),
          units_sold: m.units_sold,
          units_sold_delta: Metrics.delta(m.units_sold, m.units_sold_prev),
          avg_days_to_sell: m.avg_days_to_sell,
          avg_days_to_sell_delta: Metrics.delta(m.avg_days_to_sell, m.avg_days_to_sell_prev)
        },
        chart: Metrics.revenue_chart(m.weekly),
        pipeline:
          for {status, count} <- m.pipeline, status != "sold" do
            %{status: status, label: Unit.status_label(status), count: count}
          end,
        inventory_units: m.inventory_units,
        inventory_cost_cents: m.inventory_cost,
        listed_value_cents: m.listed_value,
        categories:
          Enum.map(m.categories, &Map.put(&1, :icon, Product.category_icon(&1.category))),
        aging: for({unit, days} <- m.aging, do: %{unit: Render.unit(unit), days: days}),
        events: Enum.map(Inventory.recent_events(9), &Render.event/1)
      }
    })
  end
end
