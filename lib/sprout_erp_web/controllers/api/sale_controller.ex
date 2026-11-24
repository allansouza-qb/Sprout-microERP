defmodule SproutErpWeb.API.SaleController do
  use SproutErpWeb, :controller

  alias SproutErp.Metrics
  alias SproutErpWeb.API.Render

  @ranges ~w(30 90 all)

  @doc """
  Completed sales in the period (`range` = 30, 90 or all) with fully loaded
  economics, plus the cancelled and returned orders kept in the ledger.
  """
  def index(conn, params) do
    range = if params["range"] in @ranges, do: params["range"], else: "30"
    %{sales: sold, closed: closed, totals: totals} = Metrics.sales(range)

    json(conn, %{
      data: %{
        range: range,
        sales: Enum.map(sold, &Render.unit/1),
        closed: Enum.map(closed, &Render.sale/1),
        totals: %{
          orders: totals.orders,
          revenue_cents: totals.revenue,
          fees_cents: totals.fees,
          fees_share: totals.fees_share,
          cost_cents: totals.cost,
          profit_cents: totals.profit,
          margin: totals.margin,
          fees_estimated: totals.fees_estimated
        }
      }
    })
  end
end
