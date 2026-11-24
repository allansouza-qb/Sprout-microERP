defmodule SproutErp.CostAllocationTest do
  @moduledoc "Lot cost allocation: whole cents, and the parts always add up to the lot total."
  use SproutErp.DataCase, async: true

  alias SproutErp.{Purchasing, Repo}
  alias SproutErp.Purchasing.Supplier
  alias SproutErp.Catalog.Product

  doctest SproutErp.Purchasing, only: [allocate_cents: 2]

  test "leftover cents go to the largest remainders, ties to the first item" do
    assert Purchasing.allocate_cents(10_000, [100, 100, 100]) == [3334, 3333, 3333]
    assert Purchasing.allocate_cents(100, [1, 1, 1, 1, 1, 1, 1]) == [15, 15, 14, 14, 14, 14, 14]
    # 1/3 of 1000 = 333.33, 2/3 = 666.67 -> the larger remainder gets the cent
    assert Purchasing.allocate_cents(1_000, [1, 2]) == [333, 667]
  end

  test "cases that used to lose a cent now close exactly" do
    weights = [59_900, 59_900, 59_900, 24_900, 24_900, 24_900, 24_900]
    assert weights |> then(&Purchasing.allocate_cents(200_000, &1)) |> Enum.sum() == 200_000
  end

  test "edge cases" do
    assert Purchasing.allocate_cents(0, [5, 7]) == [0, 0]
    assert Purchasing.allocate_cents(1, [5, 7]) == [0, 1]
    assert Purchasing.allocate_cents(999, [0, 0, 0]) == [333, 333, 333]
    assert Purchasing.allocate_cents(500, []) == []
  end

  test "sums exactly and stays within one cent of the exact share (random cases)" do
    :rand.seed(:exsss, {1, 2, 3})

    for _ <- 1..500 do
      total = :rand.uniform(5_000_000)
      weights = for _ <- 1..:rand.uniform(40), do: :rand.uniform(200_000)
      parts = Purchasing.allocate_cents(total, weights)
      sum_w = Enum.sum(weights)

      assert Enum.sum(parts) == total
      assert Enum.all?(parts, &is_integer/1)

      for {part, w} <- Enum.zip(parts, weights) do
        assert abs(part - total * w / sum_w) < 1
      end
    end
  end

  test "receiving a lot stores costs that add up to the lot total" do
    supplier = Repo.insert!(%Supplier{name: "Alloc Co.", kind: "liquidator"})

    a =
      Repo.insert!(%Product{name: "A", brand: "X", category: "Audio", msrp_cents: 10_000})

    b =
      Repo.insert!(%Product{name: "B", brand: "X", category: "Audio", msrp_cents: 10_000})

    {:ok, lot} =
      Purchasing.receive_lot(
        %{
          reference: "LOT-ALLOC",
          supplier_id: supplier.id,
          purchased_on: ~D[2026-11-24],
          total_cost_cents: 10_000
        },
        [{a.id, 2}, {b.id, 1}]
      )

    costs = Repo.preload(lot, :units).units |> Enum.map(& &1.acquisition_cost_cents)
    assert Enum.sort(costs) == [3333, 3333, 3334]
    assert Enum.sum(costs) == lot.total_cost_cents
  end
end
