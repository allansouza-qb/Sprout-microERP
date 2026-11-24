defmodule SproutErpWeb.API.FlowTest do
  @moduledoc "The whole journey through the API: receive a lot, refurbish, list and sell."
  use SproutErpWeb.ConnCase, async: true

  import Ecto.Query
  import SproutErp.InventoryFixtures

  alias SproutErp.Repo
  alias SproutErp.Inventory.Event

  test "receive a lot and walk one unit from the dock to an Amazon sale", %{conn: conn} do
    supplier = supplier_fixture()
    phone = product_fixture(category: "Smartphones", msrp_cents: 59_900)
    buds = product_fixture(category: "Audio", msrp_cents: 24_900)

    created =
      json_request(conn, :post, "/api/lots", %{
        supplier_id: supplier.id,
        purchased_on: Date.to_iso8601(SproutErp.Clock.today()),
        total_cost: "1,000.00",
        lines: [
          %{product_id: phone.id, qty: "2"},
          %{product_id: buds.id, qty: 1},
          %{product_id: "", qty: 1}
        ]
      })

    assert %{"data" => %{"id" => lot_id, "reference" => "LOT-" <> _}, "message" => message} =
             json_response(created, 201)

    assert message =~ "3 units added to inventory"

    lot = conn |> get(~p"/api/lots/#{lot_id}") |> json_response(200) |> Map.fetch!("data")
    assert length(lot["units"]) == 3
    # allocated by MSRP, in whole cents, adding up exactly to the lot cost
    assert lot["units"] |> Enum.map(& &1["acquisition_cost_cents"]) |> Enum.sum() == 100_000
    assert lot["stats"]["realized_roi"] == nil

    unit = Enum.find(lot["units"], &(&1["product"]["id"] == phone.id))
    assert unit["status"] == "received"
    id = unit["id"]

    act = fn action, body ->
      current =
        conn
        |> get(~p"/api/units/#{id}")
        |> json_response(200)
        |> get_in(["data", "lock_version"])

      json_request(
        conn,
        :post,
        "/api/units/#{id}/actions/#{action}",
        Map.put(body, :version, current)
      )
    end

    assert %{"data" => %{"status" => "inspecting"}, "message" => "Inspection started"} =
             json_response(act.("start_inspection", %{}), 200)

    graded = json_response(act.("grade", %{grade: "excellent"}), 200)
    assert graded["data"]["status"] == "refurbishing"
    assert graded["message"] =~ "Graded Excellent"
    # 76% of $599 = $455.24 -> $454.99
    assert graded["data"]["suggested_price_cents"] == 45_499

    task =
      json_request(conn, :post, "/api/units/#{id}/work_items", %{
        description: "Battery replacement",
        technician: "Maya R.",
        parts: "18.90",
        minutes: "30"
      })

    assert %{"data" => %{"work_items" => [item], "bench" => bench}} = json_response(task, 201)
    assert item["cost_cents"] == 1890 + 30 * 75
    # an open task is planned work: shown as pending, not yet part of the unit's cost
    assert bench == %{
             "completed_cents" => 0,
             "pending_cents" => 4140,
             "done" => 0,
             "total" => 1,
             "open" => 1
           }

    assert task |> json_response(201) |> get_in(["data", "refurb_cost_cents"]) == 0

    # final QC is blocked while a task is open
    assert %{"message" => "Finish all bench tasks before passing QC."} =
             json_response(act.("mark_ready", %{}), 422)

    done =
      conn |> json_request(:patch, "/api/work_items/#{item["id"]}/toggle") |> json_response(200)

    assert done["data"]["refurb_cost_cents"] == 4140

    assert %{"data" => %{"status" => "ready", "bin" => bin}} =
             json_response(act.("mark_ready", %{}), 200)

    assert is_binary(bin)

    listed = json_response(act.("list", %{price: "449.99"}), 200)
    assert listed["data"]["status"] == "listed"
    assert listed["data"]["list_price_cents"] == 44_999

    sold = json_response(act.("sell", %{price: "439.50"}), 200)["data"]
    assert sold["status"] == "sold"
    assert sold["sale_price_cents"] == 43_950
    # 8% referral + $4.45 FBA for the category, flagged as an estimate
    assert sold["fees_cents"] == round(43_950 * 0.08) + 445
    assert sold["fees_estimated"] == true

    assert sold["economics"]["profit_cents"] ==
             43_950 - sold["fees_cents"] - sold["total_cost_cents"]

    assert [%{"status" => "completed", "price_cents" => 43_950}] = sold["sales"]

    # every step is in the history
    kinds = Enum.map(sold["events"], & &1["kind"])
    assert kinds -- ~w(sold listed qc bench bench graded inspection received) == []
    assert Repo.aggregate(from(e in Event, where: e.unit_id == ^id), :count) == length(kinds)
  end

  test "an invalid lot is refused with readable messages", %{conn: conn} do
    supplier = supplier_fixture()
    product = product_fixture()

    refuse = fn body -> conn |> json_request(:post, "/api/lots", body) |> json_response(422) end

    assert %{"messages" => messages} = refuse.(%{lines: [%{product_id: product.id, qty: 1}]})
    assert "Supplier can't be blank" in messages
    assert "Total cost can't be blank" in messages

    assert %{"message" => "Lot: add at least one item"} =
             refuse.(%{
               supplier_id: supplier.id,
               total_cost: "100",
               lines: [%{product_id: product.id, qty: 0}]
             })

    assert %{"message" => "Total cost must be greater than 0"} =
             refuse.(%{
               supplier_id: supplier.id,
               total_cost: "-5",
               lines: [%{product_id: product.id, qty: 1}]
             })

    assert %{"message" => "Supplier does not exist"} =
             refuse.(%{
               supplier_id: 0,
               total_cost: "100",
               lines: [%{product_id: product.id, qty: 1}]
             })

    assert Repo.aggregate(SproutErp.Purchasing.Lot, :count) == 0
  end

  test "every read endpoint answers with data", %{conn: conn} do
    unit = unit_fixture("sold")
    unit_fixture("refurbishing")
    unit_fixture("listed")

    for path <- [
          "/api/dashboard",
          "/api/lots",
          "/api/lots/options",
          "/api/lots/#{unit.lot_id}",
          "/api/workshop",
          "/api/units",
          "/api/units?status=sold&category=Audio&q=acme",
          "/api/units/#{unit.id}",
          "/api/listings",
          "/api/sales",
          "/api/sales?range=all"
        ] do
      assert %{"data" => data} = conn |> get(path) |> json_response(200)
      assert data not in [nil, %{}, []], "#{path} returned no data"
    end
  end
end
