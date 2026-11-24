defmodule SproutErpWeb.API.ListingController do
  use SproutErpWeb, :controller

  alias SproutErp.Metrics
  alias SproutErpWeb.API.Render

  @doc "Active Amazon offers, oldest first, with the totals shown above the table."
  def index(conn, _params) do
    %{units: units, summary: summary} = Metrics.listings()

    json(conn, %{
      data: %{
        units: Enum.map(units, &Render.unit/1),
        summary: %{
          count: summary.count,
          value_cents: summary.value,
          projected_profit_cents: summary.projected_profit,
          avg_days: summary.avg_days
        }
      }
    })
  end
end
