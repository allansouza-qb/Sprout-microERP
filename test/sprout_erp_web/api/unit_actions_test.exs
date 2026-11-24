defmodule SproutErpWeb.API.UnitActionsTest do
  @moduledoc "Rules behind the unit actions: optimistic locking, pricing, bench tasks, the sales ledger."
  use SproutErpWeb.ConnCase, async: true

  import Ecto.Query
  import SproutErp.InventoryFixtures

  alias SproutErp.{Inventory, Repo}
  alias SproutErp.Inventory.{Event, Sale, Unit, WorkItem}

  @stale "This item was already updated"

  defp act(conn, unit, action, body \\ %{}),
    do: json_request(conn, :post, "/api/units/#{unit.id}/actions/#{action}", body)

  defp events(unit, kind),
    do: Repo.aggregate(from(e in Event, where: e.unit_id == ^unit.id and e.kind == ^kind), :count)

  describe "outdated screens" do
    test "the same action sent twice with the same version is applied once", %{conn: conn} do
      unit = unit_fixture("received")
      body = %{version: unit.lock_version}

      assert conn |> act(unit, "start_inspection", body) |> json_response(200)

      assert %{"error" => "stale", "message" => @stale} =
               conn |> act(unit, "start_inspection", body) |> json_response(409)

      assert Repo.get!(Unit, unit.id).status == "inspecting"
      assert events(unit, "inspection") == 1
    end

    test "a unit cannot be sold twice", %{conn: conn} do
      unit = unit_fixture("listed")
      body = %{version: unit.lock_version}

      assert conn |> act(unit, "sell", body) |> json_response(200)
      assert conn |> act(unit, "sell", body) |> json_response(409)
      # even without a version: the unit is no longer listed
      assert conn |> act(unit, "sell") |> json_response(409)

      assert events(unit, "sold") == 1
      assert Repo.aggregate(Sale, :count) == 1
    end

    test "a version from before someone else's change is refused, then the fresh one works", %{
      conn: conn
    } do
      unit = unit_fixture("listed")
      {:ok, _} = Inventory.update_list_price(reload(unit), 12_300)

      assert conn |> act(unit, "sell", %{version: unit.lock_version}) |> json_response(409)
      assert Repo.get!(Unit, unit.id).status == "listed"

      fresh = reload(unit)

      assert %{"data" => %{"sale_price_cents" => 12_300}} =
               conn |> act(unit, "sell", %{version: fresh.lock_version}) |> json_response(200)
    end

    test "actions for another stage answer 409 instead of failing", %{conn: conn} do
      unit = unit_fixture("received")

      for action <- ~w(mark_ready list reprice sell cancel_sale return_sale) do
        assert conn |> act(unit, action, %{price: "10"}) |> json_response(409), action
      end

      assert conn |> act(unit, "grade", %{grade: "good"}) |> json_response(409)
    end
  end

  describe "prices" do
    test "listing without a price uses the suggested price for the grade", %{conn: conn} do
      unit = unit_fixture("ready", grade: "good", product: product_fixture(msrp_cents: 34_999))

      # 66% of $349.99 = $230.99 -> $229.99
      assert %{"data" => %{"list_price_cents" => 22_999}} =
               conn |> act(unit, "list") |> json_response(200)
    end

    test "invalid prices are refused with a message", %{conn: conn} do
      ready = unit_fixture("ready")
      listed = unit_fixture("listed")

      for bad <- ["abc", "", "-5", 0, nil, %{}] do
        assert %{"message" => "Enter a valid price"} =
                 conn |> act(ready, "list", %{price: bad}) |> json_response(422)

        assert %{"message" => "Enter a valid sale price"} =
                 conn |> act(listed, "sell", %{price: bad}) |> json_response(422)

        assert %{"message" => "Invalid price"} =
                 conn |> act(listed, "reprice", %{price: bad}) |> json_response(422)
      end

      assert Repo.get!(Unit, ready.id).status == "ready"
      assert Repo.get!(Unit, listed.id).status == "listed"
    end

    test "selling without a price uses the list price; fees follow the price charged", %{
      conn: conn
    } do
      unit =
        unit_fixture("listed", list_price: 25_000, product: product_fixture(category: "Gaming"))

      assert %{"data" => sold} = conn |> act(unit, "sell") |> json_response(200)
      assert sold["sale_price_cents"] == 25_000
      assert sold["fees_cents"] == round(25_000 * 0.08) + 760
    end

    test "unknown grades are refused", %{conn: conn} do
      unit = unit_fixture("inspecting")

      assert %{"message" => "Unknown grade"} =
               conn |> act(unit, "grade", %{grade: "mint"}) |> json_response(422)

      assert %{"message" => "Choose a grade"} = conn |> act(unit, "grade") |> json_response(422)
    end
  end

  describe "cancelling and returning a sale" do
    test "a cancelled order goes back to its listing and stays in the ledger", %{conn: conn} do
      unit = unit_fixture("sold", list_price: 25_000, sale_price: 24_000)

      back =
        conn |> act(unit, "cancel_sale", %{reason: " Buyer changed mind "}) |> json_response(200)

      assert back["message"] =~ "back on Amazon"

      assert %{"status" => "listed", "list_price_cents" => 25_000, "sale_price_cents" => nil} =
               back["data"]

      assert [
               %{
                 "status" => "cancelled",
                 "price_cents" => 24_000,
                 "close_reason" => "Buyer changed mind"
               } = sale
             ] =
               back["data"]["sales"]

      assert sale["closed_on"] == Date.to_iso8601(SproutErp.Clock.today())
      assert events(unit, "sold") == 1
      assert events(unit, "sale_cancelled") == 1

      # it can be sold again; the ledger keeps both orders
      assert conn |> act(unit, "sell") |> json_response(200)
      assert Repo.all(from s in Sale, select: s.status, order_by: s.id) == ~w(cancelled completed)
    end

    test "a returned unit goes back to receiving for a new inspection", %{conn: conn} do
      unit = unit_fixture("sold", list_price: 25_000)

      back = conn |> act(unit, "return_sale") |> json_response(200)

      assert %{"status" => "received", "list_price_cents" => nil, "order_ref" => nil} =
               back["data"]

      assert [%{"status" => "returned", "price_cents" => 25_000, "close_reason" => nil}] =
               back["data"]["sales"]

      board = conn |> get(~p"/api/workshop") |> json_response(200) |> Map.fetch!("data")
      received = Enum.find(board, &(&1["status"] == "received"))
      assert unit.id in Enum.map(received["units"], & &1["id"])
    end

    test "closing the same sale twice is refused", %{conn: conn} do
      unit = unit_fixture("sold")
      body = %{version: unit.lock_version}

      assert conn |> act(unit, "cancel_sale", body) |> json_response(200)
      assert conn |> act(unit, "return_sale", body) |> json_response(409)
      assert Repo.all(from s in Sale, select: s.status) == ["cancelled"]
    end
  end

  describe "bench tasks" do
    defp add_task(conn, unit, body),
      do:
        json_request(
          conn,
          :post,
          "/api/units/#{unit.id}/work_items",
          Map.merge(%{description: "Pads", technician: "Maya R."}, body)
        )

    test "labor minutes must be a whole number", %{conn: conn} do
      unit = unit_fixture("refurbishing")

      for bad <- ["2.5", "abc", "-5", "1e3", 2.5, -1] do
        assert %{"message" => "Labor minutes must be a whole number" <> _} =
                 conn |> add_task(unit, %{minutes: bad}) |> json_response(422)
      end

      assert Repo.aggregate(WorkItem, :count) == 0

      assert %{"data" => %{"work_items" => [%{"labor_minutes" => 30, "parts_cents" => 1490}]}} =
               conn |> add_task(unit, %{minutes: " 30 ", parts: "14.90"}) |> json_response(201)
    end

    test "a task needs a description", %{conn: conn} do
      unit = unit_fixture("refurbishing")

      assert %{"message" => "Description can't be blank"} =
               conn |> add_task(unit, %{description: " "}) |> json_response(422)
    end

    test "only completed tasks count in the unit's cost", %{conn: conn} do
      unit = unit_fixture("refurbishing", cost: 25_000)
      # $10.00 parts + 10 min = $17.50 · $5.00 parts + 20 min = $20.00
      a =
        conn
        |> add_task(unit, %{parts: "10", minutes: 10})
        |> json_response(201)
        |> get_in(["data", "work_items", Access.at(0)])

      conn |> add_task(unit, %{parts: "5", minutes: 20}) |> json_response(201)

      toggle = fn ->
        conn
        |> json_request(:patch, "/api/work_items/#{a["id"]}/toggle")
        |> json_response(200)
        |> Map.fetch!("data")
      end

      done = toggle.()

      assert %{"completed_cents" => 1_750, "pending_cents" => 2_000, "done" => 1, "open" => 1} =
               done["bench"]

      assert done["refurb_cost_cents"] == 1_750
      assert done["total_cost_cents"] == 25_000 + 1_750

      reopened = toggle.()
      assert reopened["refurb_cost_cents"] == 0

      removed =
        conn |> delete("/api/work_items/#{a["id"]}") |> json_response(200) |> Map.fetch!("data")

      assert %{"completed_cents" => 0, "pending_cents" => 2_000, "total" => 1} = removed["bench"]

      # completing, reopening and removing a task are part of the history
      assert events(unit, "bench") == 5
    end

    test "tasks cannot change after final QC", %{conn: conn} do
      unit = unit_fixture("refurbishing")

      task =
        conn
        |> add_task(unit, %{minutes: 10})
        |> json_response(201)
        |> get_in(["data", "work_items", Access.at(0)])

      conn |> json_request(:patch, "/api/work_items/#{task["id"]}/toggle") |> json_response(200)
      {:ok, _} = Inventory.mark_ready(reload(unit))

      closed = "Bench tasks can only change before final QC."
      assert %{"message" => ^closed} = conn |> add_task(unit, %{}) |> json_response(422)

      assert %{"message" => ^closed} =
               conn
               |> json_request(:patch, "/api/work_items/#{task["id"]}/toggle")
               |> json_response(422)

      assert %{"message" => ^closed} =
               conn |> delete("/api/work_items/#{task["id"]}") |> json_response(422)

      assert Repo.get!(Unit, unit.id).refurb_cost_cents == 750
    end
  end
end
