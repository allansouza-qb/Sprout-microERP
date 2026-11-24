defmodule SproutErp.SkuSequenceTest do
  @moduledoc "SKUs come from their own sequence and are unique at the database level."
  use SproutErp.DataCase, async: false

  import Ecto.Query
  alias SproutErp.{Repo, Inventory, Purchasing}
  alias SproutErp.Purchasing.Supplier
  alias SproutErp.Catalog.Product
  alias SproutErp.Inventory.Unit

  setup do
    supplier = Repo.insert!(%Supplier{name: "SKU Co.", kind: "liquidator"})

    product =
      Repo.insert!(%Product{
        name: "Quest 3",
        brand: "Meta",
        category: "Gaming",
        msrp_cents: 49_999
      })

    %{supplier: supplier, product: product}
  end

  defp receive(ctx, ref, qty) do
    {:ok, lot} =
      Purchasing.receive_lot(
        %{
          reference: ref,
          supplier_id: ctx.supplier.id,
          purchased_on: ~D[2026-11-24],
          total_cost_cents: 10_000 * qty
        },
        [{ctx.product.id, qty}]
      )

    lot |> Repo.preload(:units) |> Map.fetch!(:units) |> Enum.map(& &1.sku) |> Enum.sort()
  end

  test "lots get consecutive SKUs from the sequence, with no gaps", ctx do
    Inventory.reset_sku_sequence(50_000)

    assert receive(ctx, "LOT-SEQ-1", 2) == ["SPR-50001", "SPR-50002"]
    assert receive(ctx, "LOT-SEQ-2", 3) == ["SPR-50003", "SPR-50004", "SPR-50005"]
  end

  test "SKUs do not depend on row ids", ctx do
    Inventory.reset_sku_sequence(70_000)
    [sku] = receive(ctx, "LOT-SEQ-3", 1)
    unit = Repo.get_by!(Unit, sku: sku)

    assert sku == "SPR-70001"
    refute sku == "SPR-#{unit.id + 10_000}"

    # deleting units does not make the sequence reuse or jump numbers
    Repo.delete_all(Unit)
    assert receive(ctx, "LOT-SEQ-4", 1) == ["SPR-70002"]
  end

  test "reserve_sku_numbers hands out blocks atomically" do
    Inventory.reset_sku_sequence(100)
    assert Inventory.reserve_sku_numbers(5) == 101
    assert Inventory.reserve_sku_numbers(1) == 106
  end

  test "the database enforces unique SKUs", ctx do
    [sku] = receive(ctx, "LOT-SEQ-5", 1)
    existing = Repo.get_by!(Unit, sku: sku)

    duplicate =
      Unit.changeset(%Unit{}, %{
        sku: sku,
        product_id: existing.product_id,
        lot_id: existing.lot_id,
        status: "received"
      })

    assert {:error, changeset} = Repo.insert(duplicate)
    assert {"has already been taken", _} = changeset.errors[:sku]

    # bypassing the changeset still hits the unique index in the database
    assert_raise Ecto.ConstraintError, fn ->
      Repo.insert!(%Unit{
        sku: sku,
        product_id: existing.product_id,
        lot_id: existing.lot_id,
        status: "received"
      })
    end

    %{rows: [[definition]]} =
      Repo.query!(
        "SELECT indexdef FROM pg_indexes WHERE tablename = 'units' AND indexname = 'units_sku_index'"
      )

    assert definition =~ "UNIQUE INDEX"
  end

  test "the sequence lives in its own table" do
    assert [{"unit_sku", value}] =
             Repo.all(from s in "sequences", select: {s.name, s.value})

    assert is_integer(value)
  end
end
