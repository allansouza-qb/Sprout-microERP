defmodule SproutErp.SupplierStatsTest do
  @moduledoc "Supplier figures come from recorded sales: sell-through and margin."
  use SproutErpWeb.ConnCase, async: false

  alias SproutErp.{Repo, Inventory, Purchasing}
  alias SproutErp.Purchasing.Supplier
  alias SproutErp.Catalog.Product

  setup do
    supplier =
      Repo.insert!(%Supplier{name: "Rated Co.", kind: "auction", location: "Austin, TX"})

    product =
      Repo.insert!(%Product{name: "QC45", brand: "Bose", category: "Audio", msrp_cents: 32_900})

    {:ok, lot} =
      Purchasing.receive_lot(
        %{
          reference: "LOT-SUP-1",
          supplier_id: supplier.id,
          purchased_on: ~D[2026-11-01],
          total_cost_cents: 10_000
        },
        [{product.id, 2}]
      )

    [unit | _] = Repo.preload(lot, :units).units
    {:ok, _} = Inventory.start_inspection(Inventory.get_unit!(unit.id))
    {:ok, _} = Inventory.assign_grade(Inventory.get_unit!(unit.id), "good")
    {:ok, _} = Inventory.mark_ready(Inventory.get_unit!(unit.id))
    {:ok, _} = Inventory.list_on_amazon(Inventory.get_unit!(unit.id), 20_000)
    {:ok, _} = Inventory.record_sale(Inventory.get_unit!(unit.id))

    %{supplier: supplier}
  end

  test "sell-through and average margin come from recorded sales", %{supplier: supplier} do
    [stats] = Purchasing.supplier_stats() |> Enum.filter(&(&1.supplier.id == supplier.id))

    assert stats.units == 2
    assert stats.sold == 1
    assert stats.sell_through == 0.5
    # 20_000 sale − (8% referral 1_600 + Audio FBA 445) − 5_000 allocated cost
    assert stats.avg_margin == 12_955 / 20_000
  end

  test "a supplier with no sales has no margin yet" do
    quiet = Repo.insert!(%Supplier{name: "Quiet Co.", kind: "liquidator"})
    product = Repo.insert!(%Product{name: "X", brand: "Y", category: "Audio", msrp_cents: 1_000})

    {:ok, _} =
      Purchasing.receive_lot(
        %{
          reference: "LOT-SUP-2",
          supplier_id: quiet.id,
          purchased_on: ~D[2026-11-02],
          total_cost_cents: 500
        },
        [{product.id, 1}]
      )

    [stats] = Purchasing.supplier_stats() |> Enum.filter(&(&1.supplier.id == quiet.id))
    assert stats.sell_through == 0.0
    assert stats.avg_margin == nil
  end
end
