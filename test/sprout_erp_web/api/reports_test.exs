defmodule SproutErpWeb.API.ReportsTest do
  @moduledoc "Numbers behind the dashboard, purchasing, listings and sales screens."
  use SproutErpWeb.ConnCase, async: true

  import Ecto.Query
  import SproutErp.InventoryFixtures

  alias SproutErp.{Clock, Inventory, Repo}
  alias SproutErp.Inventory.{Sale, Unit}

  defp data(conn, path), do: conn |> get(path) |> json_response(200) |> Map.fetch!("data")

  describe "dashboard" do
    test "greeting and date follow the company time zone", %{conn: conn} do
      dash = data(conn, "/api/dashboard")

      assert dash["greeting"] == Clock.greeting()
      assert dash["today"] == Date.to_iso8601(Clock.today())
    end

    test "30-day figures, margin, pipeline and chart scale", %{conn: conn} do
      # Audio: fees 8% + $4.45; lot cost $100 per unit
      unit_fixture("sold", list_price: 30_000)
      unit_fixture("listed", list_price: 20_000)
      unit_fixture("refurbishing")

      dash = data(conn, "/api/dashboard")
      profit = 30_000 - (2_400 + 445) - 10_000

      assert %{"revenue_cents" => 30_000, "profit_cents" => ^profit, "units_sold" => 1} =
               dash["kpis"]

      assert_in_delta dash["kpis"]["margin"], profit / 30_000, 1.0e-9
      # nothing sold in the previous 30 days: no delta to show
      assert dash["kpis"]["revenue_delta"] == nil

      assert Map.new(dash["pipeline"], &{&1["status"], &1["count"]}) ==
               %{
                 "received" => 0,
                 "inspecting" => 0,
                 "refurbishing" => 1,
                 "ready" => 0,
                 "listed" => 1
               }

      assert dash["inventory_units"] == 2
      assert dash["listed_value_cents"] == 20_000

      chart = dash["chart"]
      assert length(chart["weeks"]) == 12
      assert List.last(chart["weeks"])["revenue"] == 30_000
      assert chart["top"] >= 30_000
      assert hd(chart["ticks"]) == chart["top"]
      assert List.last(chart["ticks"]) == 0

      assert [%{"kind" => _, "unit" => %{"sku" => "SPR-" <> _}} | _] = dash["events"]
    end
  end

  describe "purchasing" do
    test "realized ROI is empty until the lot's first sale; projected adds pending bench work", %{
      conn: conn
    } do
      product = product_fixture(category: "Audio", msrp_cents: 24_900)
      lot = lot_fixture([{product, 2}], %{total_cost_cents: 20_000})
      [a, b] = Enum.sort_by(lot.units, & &1.sku)

      stats = fn -> data(conn, "/api/lots/#{lot.id}")["stats"] end

      fresh = stats.()
      assert fresh["realized_roi"] == nil
      assert fresh["realized_profit"] == nil
      assert is_float(fresh["projected_roi"])

      # A: sold for $300.00 -> fees $24.00 + $4.45
      {:ok, _} = Inventory.start_inspection(reload(a))
      {:ok, _} = Inventory.assign_grade(reload(a), "good")
      {:ok, _} = Inventory.mark_ready(reload(a))
      {:ok, _} = Inventory.list_on_amazon(reload(a), 30_000)
      {:ok, _} = Inventory.record_sale(reload(a))

      # B: on the bench — $17.50 completed, $20.00 still pending
      {:ok, _} = Inventory.start_inspection(reload(b))
      {:ok, _} = Inventory.assign_grade(reload(b), "excellent")

      {:ok, done} =
        Inventory.add_work_item(reload(b), %{
          "description" => "Tips",
          "parts_cents" => 1_000,
          "labor_minutes" => 10
        })

      {:ok, _} = Inventory.toggle_work_item(done.id)

      {:ok, _} =
        Inventory.add_work_item(reload(b), %{
          "description" => "Hinge",
          "parts_cents" => 500,
          "labor_minutes" => 20
        })

      st = stats.()
      assert st["bench_completed"] == 1_750
      assert st["bench_pending"] == 2_000
      assert st["invested"] == 20_000 + 1_750
      assert st["net"] == 30_000 - 2_845
      assert st["realized_profit"] == 27_155 - 21_750
      assert_in_delta st["realized_roi"], 5_405 / 21_750, 1.0e-9

      b_price = Inventory.suggested_price_cents(reload(b))
      b_net = b_price - Unit.estimated_fees_cents(reload(b), b_price)
      assert st["projected_cost"] == st["invested"] + 2_000
      assert st["projected_net"] == 27_155 + b_net

      assert_in_delta st["projected_roi"],
                      (st["projected_net"] - st["projected_cost"]) / st["projected_cost"],
                      1.0e-9

      assert %{"lots" => [%{"reference" => ref, "stats" => %{"sold" => 1, "units" => 2}}]} =
               data(conn, "/api/lots")

      assert ref == lot.reference
    end

    test "supplier cards use recorded sales, not a rating", %{conn: conn} do
      supplier = supplier_fixture(%{name: "Rated Co."})
      lot = lot_fixture([{product_fixture(), 2}], %{supplier: supplier, total_cost_cents: 10_000})
      [unit | _] = lot.units
      {:ok, _} = Inventory.start_inspection(reload(unit))
      {:ok, _} = Inventory.assign_grade(reload(unit), "good")
      {:ok, _} = Inventory.mark_ready(reload(unit))
      {:ok, _} = Inventory.list_on_amazon(reload(unit), 20_000)
      {:ok, _} = Inventory.record_sale(reload(unit))

      assert [card] = data(conn, "/api/lots")["suppliers"]

      assert %{
               "name" => "Rated Co.",
               "kind_label" => "Liquidator",
               "units" => 2,
               "sold" => 1,
               "sell_through" => 0.5
             } = card

      # 20_000 − (1_600 + 445) − 5_000 allocated cost
      assert_in_delta card["avg_margin"], 12_955 / 20_000, 1.0e-9
      refute Map.has_key?(card, "rating")
    end
  end

  describe "inventory" do
    test "filters by stage, category and search", %{conn: conn} do
      phone = product_fixture(name: "iPhone 13", brand: "Apple", category: "Smartphones")
      sold = unit_fixture("sold", product: phone)
      unit_fixture("received", product: phone)
      audio = unit_fixture("received", product: product_fixture(name: "QC45", category: "Audio"))

      ids = fn query -> data(conn, "/api/units?" <> query)["units"] |> Enum.map(& &1["id"]) end

      assert ids.("status=sold") == [sold.id]
      assert ids.("category=Audio") == [audio.id]
      assert length(ids.("q=IPHONE")) == 2
      assert ids.("q=" <> String.downcase(audio.sku)) == [audio.id]
      # LIKE wildcards in the search are taken literally
      assert ids.("q=%25") == []

      assert data(conn, "/api/units")["counts"] == %{"received" => 2, "sold" => 1}
    end
  end

  describe "listings and sales" do
    test "listings are oldest first with estimated fees and projected profit", %{conn: conn} do
      newer = unit_fixture("listed", list_price: 20_000)
      older = unit_fixture("listed", list_price: 30_000)

      Repo.update_all(from(u in Unit, where: u.id == ^older.id),
        set: [listed_on: Date.add(Clock.today(), -30)]
      )

      listings = data(conn, "/api/listings")
      assert Enum.map(listings["units"], & &1["id"]) == [older.id, newer.id]

      assert [
               %{"days_listed" => 30, "estimated_fees_cents" => 2_845, "profit_cents" => 17_155},
               %{"days_listed" => 0}
             ] =
               listings["units"]

      assert %{"count" => 2, "value_cents" => 50_000, "avg_days" => 15.0} = listings["summary"]
      assert listings["summary"]["projected_profit_cents"] == 17_155 + (20_000 - 2_045 - 10_000)
    end

    test "sales are newest first, limited to the period, with totals flagged as estimates", %{
      conn: conn
    } do
      [a, b, c] = for _ <- 1..3, do: unit_fixture("sold", list_price: 20_000)
      today = Clock.today()

      # Sep 28, Oct 3 and Nov 1 would sort wrong by day of month
      for {unit, days} <- [{a, 3}, {b, 40}, {c, 12}] do
        date = Date.add(today, -days)
        Repo.update_all(from(u in Unit, where: u.id == ^unit.id), set: [sold_on: date])
        Repo.update_all(from(s in Sale, where: s.unit_id == ^unit.id), set: [sold_on: date])
      end

      month = data(conn, "/api/sales")
      assert month["range"] == "30"
      assert Enum.map(month["sales"], & &1["id"]) == [a.id, c.id]

      assert %{
               "orders" => 2,
               "revenue_cents" => 40_000,
               "fees_cents" => 4_090,
               "cost_cents" => 20_000,
               "fees_estimated" => true
             } =
               month["totals"]

      assert month["totals"]["profit_cents"] == 40_000 - 4_090 - 20_000

      assert Enum.map(data(conn, "/api/sales?range=all")["sales"], & &1["id"]) == [
               a.id,
               c.id,
               b.id
             ]

      # an unknown range falls back to 30 days
      assert data(conn, "/api/sales?range=7")["range"] == "30"
    end

    test "cancelled and returned orders are listed apart and are not revenue", %{conn: conn} do
      kept = unit_fixture("sold", list_price: 20_000)
      returned = unit_fixture("sold", list_price: 30_000)
      {:ok, _} = Inventory.return_sale(reload(returned), "Damaged, in transit")

      sales = data(conn, "/api/sales?range=all")
      assert Enum.map(sales["sales"], & &1["id"]) == [kept.id]
      assert sales["totals"]["revenue_cents"] == 20_000

      assert [
               %{
                 "status" => "returned",
                 "status_label" => "Returned",
                 "close_reason" => "Damaged, in transit",
                 "price_cents" => 30_000,
                 "unit" => %{"sku" => sku}
               }
             ] =
               sales["closed"]

      assert sku == returned.sku
    end

    test "fees stop being an estimate only when the actual charge is recorded", %{conn: conn} do
      unit = unit_fixture("sold")
      assert data(conn, "/api/units/#{unit.id}")["fees_estimated"] == true
      assert data(conn, "/api/sales")["totals"]["fees_estimated"] == true

      Repo.update_all(from(u in Unit, where: u.id == ^unit.id), set: [fees_estimated: false])
      assert data(conn, "/api/units/#{unit.id}")["fees_estimated"] == false
      assert data(conn, "/api/sales")["totals"]["fees_estimated"] == false
    end
  end
end
