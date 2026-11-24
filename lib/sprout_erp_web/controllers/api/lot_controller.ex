defmodule SproutErpWeb.API.LotController do
  use SproutErpWeb, :controller

  alias SproutErp.{Clock, Money, Purchasing}
  alias SproutErpWeb.API.Render

  action_fallback SproutErpWeb.API.FallbackController

  def index(conn, _params) do
    lots = Purchasing.list_lots()

    json(conn, %{
      data: %{
        suppliers: Enum.map(Purchasing.supplier_stats(lots), &Render.supplier_stats/1),
        lots: Enum.map(lots, &Render.lot/1)
      }
    })
  end

  @doc "What the receive-lot form needs: suppliers, products and today's date."
  def options(conn, _params) do
    json(conn, %{
      data: %{
        today: Clock.today(),
        suppliers: Enum.map(Purchasing.list_suppliers(), &Render.supplier/1),
        products: Enum.map(Purchasing.list_products(), &Render.product/1)
      }
    })
  end

  def show(conn, %{"id" => id}) do
    lot = Purchasing.get_lot!(id)

    json(conn, %{
      data: Map.put(Render.lot(lot), :units, Enum.map(lot.units, &Render.unit/1))
    })
  end

  def create(conn, params) do
    date = purchase_date(params["purchased_on"])
    lines = lines(params["lines"])

    attrs = %{
      reference: Purchasing.next_reference(date),
      supplier_id: params["supplier_id"],
      purchased_on: date,
      total_cost_cents: cents(params["total_cost"]),
      notes: params["notes"]
    }

    with {:ok, lot} <- Purchasing.receive_lot(attrs, lines) do
      units = lines |> Enum.map(&elem(&1, 1)) |> Enum.sum()

      conn
      |> put_status(:created)
      |> json(%{
        data: %{id: lot.id, reference: lot.reference},
        message: "#{lot.reference} received · #{units} units added to inventory"
      })
    end
  end

  defp purchase_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> Clock.today()
    end
  end

  defp purchase_date(_), do: Clock.today()

  defp cents(value) when is_binary(value) or is_number(value), do: Money.to_cents(value)
  defp cents(_), do: nil

  # [%{"product_id" => 3, "qty" => "2"}, …] -> [{3, 2}, …]; rows without a
  # product or with a non-positive quantity are ignored (max 200 per row).
  defp lines(lines) when is_list(lines) do
    for %{} = line <- lines,
        product_id = positive_int(line["product_id"]),
        qty = positive_int(line["qty"]),
        do: {product_id, min(qty, 200)}
  end

  defp lines(_), do: []

  defp positive_int(n) when is_integer(n) and n > 0, do: n

  defp positive_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  defp positive_int(_), do: nil
end
