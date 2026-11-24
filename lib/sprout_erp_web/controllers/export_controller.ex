defmodule SproutErpWeb.ExportController do
  @moduledoc "CSV downloads that apply the same filters as the screen they come from."
  use SproutErpWeb, :controller

  alias SproutErp.{Inventory, CSV, Clock}
  alias SproutErp.Inventory.Unit

  # /export/inventory.csv?status=&category=&q=  — same filters as /inventory
  def inventory(conn, params) do
    units =
      Inventory.list_units(
        status: params["status"],
        category: params["category"],
        search: params["q"]
      )

    header = [
      "sku",
      "serial",
      "brand",
      "product",
      "category",
      "grade",
      "status",
      "lot",
      "supplier",
      "received_on",
      "listed_on",
      "sold_on",
      "days_in_stock",
      "bin",
      "acquisition_cost",
      "refurb_cost_completed",
      "cost_basis",
      "list_price",
      "sale_price",
      "fees",
      "fees_estimated",
      "profit_est"
    ]

    rows =
      for u <- units do
        [
          u.sku,
          u.serial,
          u.product.brand,
          u.product.name,
          u.product.category,
          u.grade,
          u.status,
          u.lot.reference,
          u.lot.supplier.name,
          u.received_on,
          u.listed_on,
          u.sold_on,
          Unit.days_in_stock(u),
          u.bin,
          CSV.money(u.acquisition_cost_cents),
          CSV.money(u.refurb_cost_cents),
          CSV.money(Unit.total_cost_cents(u)),
          CSV.money(u.list_price_cents),
          CSV.money(u.sale_price_cents),
          CSV.money(u.fees_cents),
          if(u.status == "sold", do: u.fees_estimated),
          CSV.money(Unit.profit_cents(u))
        ]
      end

    download(conn, "sprout-inventory-#{Clock.today()}.csv", [header | rows])
  end

  # /export/sales.csv?range=30|90|all  — same period as /sales; every ledger
  # row in the period, with its status (completed, cancelled, returned)
  def sales(conn, params) do
    range = if params["range"] in ["30", "90", "all"], do: params["range"], else: "30"

    header = [
      "sold_on",
      "order_ref",
      "status",
      "closed_on",
      "close_reason",
      "sku",
      "brand",
      "product",
      "category",
      "grade",
      "sale_price",
      "fees",
      "fees_estimated",
      "cost_basis",
      "profit_est"
    ]

    rows =
      for s <- Inventory.list_sales(range) do
        u = s.unit
        completed? = s.status == "completed"

        [
          s.sold_on,
          s.order_ref,
          s.status,
          s.closed_on,
          s.close_reason,
          u.sku,
          u.product.brand,
          u.product.name,
          u.product.category,
          u.grade,
          CSV.money(s.price_cents),
          CSV.money(s.fees_cents),
          s.fees_estimated,
          if(completed?, do: CSV.money(Unit.total_cost_cents(u))),
          if(completed?,
            do: CSV.money(s.price_cents - s.fees_cents - Unit.total_cost_cents(u))
          )
        ]
      end

    label = if range == "all", do: "all", else: "#{range}d"
    download(conn, "sprout-sales-#{label}-#{Clock.today()}.csv", [header | rows])
  end

  defp download(conn, filename, rows) do
    send_download(conn, {:binary, CSV.encode(rows)},
      filename: filename,
      content_type: "text/csv",
      charset: "utf-8"
    )
  end
end
