defmodule SproutErp.InventoryTest do
  @moduledoc "Context-level rules: optimistic locking and the bench cost split."
  use SproutErp.DataCase, async: true

  import SproutErp.InventoryFixtures

  alias SproutErp.{Inventory, Repo}
  alias SproutErp.Inventory.{Sale, Unit}

  describe "optimistic locking" do
    test "the same unit cannot be sold twice from two copies" do
      listed = unit_fixture("listed")
      tab_a = reload(listed)
      tab_b = reload(listed)

      assert {:ok, %Unit{status: "sold"}} = Inventory.record_sale(tab_a)
      assert {:error, :stale} = Inventory.record_sale(tab_b)
      assert {:error, :stale} = Inventory.record_sale(reload(listed))
      assert Repo.aggregate(Sale, :count) == 1
    end

    test "an outdated copy in the same stage is rejected by its version" do
      listed = unit_fixture("listed")
      tab_a = reload(listed)
      tab_b = reload(listed)

      assert {:ok, _} = Inventory.update_list_price(tab_a, 10_000)
      assert {:error, :stale} = Inventory.update_list_price(tab_b, 20_000)
      assert Repo.get!(Unit, listed.id).list_price_cents == 10_000
    end

    test "calls for another stage return :stale instead of raising" do
      fresh = unit_fixture("received")

      assert {:error, :stale} = Inventory.assign_grade(fresh, "good")
      assert {:error, :stale} = Inventory.mark_ready(fresh)
      assert {:error, :stale} = Inventory.list_on_amazon(fresh)
      assert {:error, :stale} = Inventory.record_sale(fresh)
      assert {:error, :stale} = Inventory.update_list_price(fresh, 100)
      assert {:error, :stale} = Inventory.cancel_sale(fresh)
      assert {:error, :stale} = Inventory.return_sale(fresh)
    end

    test "the version the client saw replaces the loaded one" do
      unit = unit_fixture("received")

      assert Inventory.with_seen_version(unit, "7").lock_version == 7
      assert Inventory.with_seen_version(unit, nil).lock_version == unit.lock_version
      assert Inventory.with_seen_version(unit, "abc").lock_version == unit.lock_version
    end
  end

  describe "bench work" do
    test "cost is split between completed and pending tasks" do
      unit = unit_fixture("refurbishing")

      {:ok, a} =
        Inventory.add_work_item(unit, %{
          "description" => "Battery",
          "parts_cents" => 1_000,
          "labor_minutes" => 10
        })

      {:ok, _} =
        Inventory.add_work_item(unit, %{
          "description" => "Polish",
          "parts_cents" => 500,
          "labor_minutes" => 20
        })

      assert Inventory.bench_costs(reload(unit).work_items) == %{completed: 0, pending: 3_750}
      assert reload(unit).refurb_cost_cents == 0

      {:ok, _} = Inventory.toggle_work_item(a.id)
      assert Inventory.bench_costs(reload(unit).work_items) == %{completed: 1_750, pending: 2_000}
      assert reload(unit).refurb_cost_cents == 1_750
    end

    test "tasks are frozen once the unit leaves the workshop" do
      unit = unit_fixture("refurbishing")

      {:ok, task} =
        Inventory.add_work_item(unit, %{"description" => "Battery", "labor_minutes" => 10})

      {:ok, _} = Inventory.toggle_work_item(task.id)
      {:ok, _} = Inventory.mark_ready(reload(unit))

      assert {:error, "Bench tasks can only change" <> _} =
               Inventory.add_work_item(reload(unit), %{"description" => "x"})

      assert {:error, "Bench tasks can only change" <> _} = Inventory.toggle_work_item(task.id)
      assert {:error, "Bench tasks can only change" <> _} = Inventory.delete_work_item(task.id)
    end
  end
end
