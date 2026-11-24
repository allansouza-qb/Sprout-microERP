defmodule SproutErpWeb.ExportControllerTest do
  @moduledoc "CSV exports follow the screen filters and are safe to open in a spreadsheet."
  use SproutErpWeb.ConnCase, async: false

  import Ecto.Query
  alias SproutErp.{Repo, Inventory, Purchasing, CSV}
  alias SproutErp.Purchasing.Supplier
  alias SproutErp.Catalog.Product
  alias SproutErp.Inventory.Sale

  setup do
    supplier = Repo.insert!(%Supplier{name: "Export Co.", kind: "liquidator"})

    phone =
      Repo.insert!(%Product{
        name: "iPhone 13",
        brand: "Apple",
        category: "Smartphones",
        msrp_cents: 59_900
      })

    # a name that needs quoting and one that looks like a formula
    tricky =
      Repo.insert!(%Product{
        name: ~s|=HYPERLINK("x"), "Pro"|,
        brand: "Acme",
        category: "Audio",
        msrp_cents: 10_000
      })

    {:ok, lot} =
      Purchasing.receive_lot(
        %{
          reference: "LOT-EXP",
          supplier_id: supplier.id,
          purchased_on: ~D[2026-08-01],
          total_cost_cents: 30_000
        },
        [{phone.id, 2}, {tricky.id, 1}]
      )

    units = Repo.preload(lot, units: :product).units
    [p1, p2] = Enum.filter(units, &(&1.product_id == phone.id))
    [t] = Enum.filter(units, &(&1.product_id == tricky.id))

    # p1 and p2 get sold; t stays received
    for u <- [p1, p2] do
      {:ok, _} = Inventory.start_inspection(Inventory.get_unit!(u.id))
      {:ok, _} = Inventory.assign_grade(Inventory.get_unit!(u.id), "good")
      {:ok, _} = Inventory.mark_ready(Inventory.get_unit!(u.id))
      {:ok, _} = Inventory.list_on_amazon(Inventory.get_unit!(u.id), 40_000)
      {:ok, _} = Inventory.record_sale(Inventory.get_unit!(u.id))
    end

    # p2's sale happened 120 days ago, then it was returned
    old = Date.add(SproutErp.Clock.today(), -120)
    Repo.update_all(from(s in Sale, where: s.unit_id == ^p2.id), set: [sold_on: old])
    {:ok, _} = Inventory.return_sale(Inventory.get_unit!(p2.id), "Damaged, in transit")

    %{p1: Inventory.get_unit!(p1.id), p2: Inventory.get_unit!(p2.id), t: t}
  end

  defp csv_lines(conn), do: conn.resp_body |> String.split("\r\n", trim: true)

  test "inventory export applies status, category and search", %{conn: conn} = ctx do
    conn = get(conn, ~p"/export/inventory.csv?status=sold")

    assert response_content_type(conn, :csv) =~ "text/csv"
    assert get_resp_header(conn, "content-disposition") |> hd() =~ "sprout-inventory-"

    [header | rows] = csv_lines(conn)
    assert header =~ "sku,serial,brand,product"
    assert length(rows) == 1
    assert hd(rows) =~ ctx.p1.sku

    rows = conn |> get(~p"/export/inventory.csv?category=Audio") |> csv_lines() |> tl()
    assert length(rows) == 1
    assert hd(rows) =~ ctx.t.sku

    rows = conn |> get(~p"/export/inventory.csv?q=iphone") |> csv_lines() |> tl()
    assert length(rows) == 2
  end

  test "sales export applies the period and includes the ledger status", %{conn: conn} = ctx do
    rows = conn |> get(~p"/export/sales.csv?range=30") |> csv_lines() |> tl()
    assert length(rows) == 1
    assert hd(rows) =~ ctx.p1.sku
    assert hd(rows) =~ ",completed,"

    rows = conn |> get(~p"/export/sales.csv?range=all") |> csv_lines() |> tl()
    assert length(rows) == 2
    assert Enum.any?(rows, &(&1 =~ ",returned," and &1 =~ "Damaged, in transit"))
  end

  test "CSV cells are quoted and formula-like text is neutralized" do
    out = CSV.encode([[~s|=HYPERLINK("x"), "Pro"|, "-5 off", CSV.money(-1250), 3, nil]])
    assert out == ~s|"'=HYPERLINK(""x""), ""Pro""",'-5 off,-12.50,3,\r\n|
  end
end
