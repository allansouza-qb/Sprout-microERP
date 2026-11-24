defmodule SproutErp.ClockTest do
  @moduledoc "Company time zone: one config drives today, displayed times and the greeting."
  use SproutErpWeb.ConnCase, async: false

  alias SproutErp.{Clock, Repo, Inventory, Purchasing}
  alias SproutErp.Purchasing.Supplier
  alias SproutErp.Catalog.Product

  setup do
    original = Application.fetch_env!(:sprout_erp, :time_zone)
    on_exit(fn -> Application.put_env(:sprout_erp, :time_zone, original) end)
    Application.put_env(:sprout_erp, :time_zone, "America/Sao_Paulo")
    :ok
  end

  defp use_zone(zone), do: Application.put_env(:sprout_erp, :time_zone, zone)

  test "the time zone is read from the single config entry" do
    assert Clock.time_zone() == "America/Sao_Paulo"
    use_zone("Asia/Tokyo")
    assert Clock.time_zone() == "Asia/Tokyo"
  end

  test "today follows the company zone, not UTC" do
    # 01:30 UTC on the 25th is still 22:30 on the 24th in São Paulo (UTC−3)
    assert Clock.today(~U[2026-11-25 01:30:00Z]) == ~D[2026-11-24]

    # 16:00 UTC on the 24th is already the 25th in Tokyo (UTC+9)
    use_zone("Asia/Tokyo")
    assert Clock.today(~U[2026-11-24 16:00:00Z]) == ~D[2026-11-25]
  end

  test "greeting follows the local hour" do
    assert Clock.greeting(~U[2026-11-24 11:00:00Z]) == "Good morning"
    assert Clock.greeting(~U[2026-11-24 17:00:00Z]) == "Good afternoon"
    assert Clock.greeting(~U[2026-11-24 23:30:00Z]) == "Good evening"
    assert Clock.greeting(~U[2026-11-25 04:00:00Z]) == "Good evening"
  end

  test "utc_at converts company wall-clock time to UTC" do
    assert Clock.utc_at(~D[2026-11-24], ~T[09:00:00]) == ~U[2026-11-24 12:00:00Z]
  end

  test "business dates written by the system use the company today" do
    supplier = Repo.insert!(%Supplier{name: "Clock Co.", kind: "trade_in"})

    product =
      Repo.insert!(%Product{
        name: "Pixel 8",
        brand: "Google",
        category: "Smartphones",
        msrp_cents: 69_900
      })

    # Between them, these two zones differ from the UTC date at any hour of the day.
    for zone <- ["Pacific/Kiritimati", "Etc/GMT+12"] do
      use_zone(zone)

      {:ok, lot} =
        Purchasing.receive_lot(
          %{
            reference: "LOT-#{zone}",
            supplier_id: supplier.id,
            purchased_on: Clock.today(),
            total_cost_cents: 20_000
          },
          [{product.id, 1}]
        )

      [unit] = Repo.preload(lot, :units).units
      {:ok, _} = Inventory.start_inspection(Inventory.get_unit!(unit.id))
      {:ok, _} = Inventory.assign_grade(Inventory.get_unit!(unit.id), "good")
      {:ok, _} = Inventory.mark_ready(Inventory.get_unit!(unit.id))
      {:ok, listed} = Inventory.list_on_amazon(Inventory.get_unit!(unit.id))
      {:ok, sold} = Inventory.record_sale(Inventory.get_unit!(listed.id))

      assert listed.listed_on == Clock.today()
      assert sold.sold_on == Clock.today()
    end
  end
end
