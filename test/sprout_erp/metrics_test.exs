defmodule SproutErp.MetricsTest do
  @moduledoc "Dashboard numbers computed in the database match the per-unit rules."
  use SproutErp.DataCase, async: true

  import Ecto.Query
  import SproutErp.InventoryFixtures

  alias SproutErp.{Metrics, Repo}
  alias SproutErp.Inventory.Unit

  @today ~D[2026-11-24]

  defp set(unit, fields) do
    Repo.update_all(from(u in Unit, where: u.id == ^unit.id), set: fields)
    reload(unit)
  end

  # A sold unit: lot cost $100, Audio fees = 8% + $4.45.
  defp sold(price, days_ago, opts \\ []) do
    "sold"
    |> unit_fixture([list_price: price] ++ opts)
    |> set(
      sold_on: Date.add(@today, -days_ago),
      received_on: Date.add(@today, -days_ago - Keyword.get(opts, :days_to_sell, 10))
    )
  end

  test "30-day totals and the previous 30 days come from the sale date" do
    a = sold(30_000, 0, days_to_sell: 4)
    b = sold(20_000, 29, days_to_sell: 8)
    c = sold(40_000, 30)
    _too_old = sold(50_000, 60)

    m = Metrics.dashboard(@today)

    assert m.revenue == 50_000
    assert m.profit == Unit.profit_cents(a) + Unit.profit_cents(b)
    assert m.units_sold == 2
    assert m.avg_days_to_sell == 6.0

    assert m.revenue_prev == 40_000
    assert m.profit_prev == Unit.profit_cents(c)
    assert m.units_sold_prev == 1
  end

  test "with no sales the totals are zero, not nil" do
    unit_fixture("received")
    m = Metrics.dashboard(@today)

    assert %{revenue: 0, profit: 0, units_sold: 0, avg_days_to_sell: +0.0} = m
    assert m.categories == []
    assert Enum.all?(m.weekly, &(&1.revenue == 0 and &1.units == 0))
  end

  test "stock counts everything not sold; listed value only what is on Amazon" do
    sold(30_000, 1)
    listed = unit_fixture("listed", list_price: 20_000, cost: 8_000)
    bench = unit_fixture("refurbishing", cost: 5_000)

    m = Metrics.dashboard(@today)

    assert m.inventory_units == 2
    assert m.inventory_cost == Unit.total_cost_cents(listed) + Unit.total_cost_cents(bench)
    assert m.listed_value == 20_000

    assert m.pipeline == [
             {"received", 0},
             {"inspecting", 0},
             {"refurbishing", 1},
             {"ready", 0},
             {"listed", 1},
             {"sold", 1}
           ]
  end

  test "weekly buckets run Monday to Sunday and keep empty weeks" do
    # 2026-11-24 is a Tuesday: the current week starts on Monday the 23rd
    sold(10_000, 1)
    sold(20_000, 2)
    sold(40_000, 8)

    weeks = Metrics.weekly(@today, 12)

    assert length(weeks) == 12
    assert Enum.map(weeks, & &1.start) |> List.last() == ~D[2026-11-23]
    assert Enum.all?(weeks, &(Date.day_of_week(&1.start) == 1))

    assert [%{revenue: 0}, %{revenue: 60_000, units: 2}, %{revenue: 10_000, units: 1}] =
             Enum.take(weeks, -3)
  end

  test "categories are grouped in the database, best profit first" do
    phone = product_fixture(category: "Smartphones")
    a = sold(60_000, 1, product: phone)
    b = sold(50_000, 100, product: phone)
    c = sold(30_000, 2)

    assert [phones, audio] = Metrics.categories()

    assert %{category: "Smartphones", units: 2, revenue: 110_000} = phones
    assert phones.profit == Unit.profit_cents(a) + Unit.profit_cents(b)
    assert_in_delta phones.margin, phones.profit / 110_000, 1.0e-9

    assert %{category: "Audio", units: 1, revenue: 30_000} = audio
    assert audio.profit == Unit.profit_cents(c)
  end

  test "aging lists workshop units after 10 days and listings after 21, longest first" do
    stuck = "refurbishing" |> unit_fixture() |> set(received_on: Date.add(@today, -15))
    _fresh = "inspecting" |> unit_fixture() |> set(received_on: Date.add(@today, -10))

    stale = "listed" |> unit_fixture() |> set(listed_on: Date.add(@today, -30))
    # long in stock, but only just listed: the listing age is what counts
    _relisted =
      "listed"
      |> unit_fixture()
      |> set(received_on: Date.add(@today, -90), listed_on: Date.add(@today, -21))

    _shelf = "ready" |> unit_fixture() |> set(received_on: Date.add(@today, -90))
    sold(30_000, 40)

    assert [{first, 30}, {second, 15}] = Metrics.aging(@today)
    assert first.id == stale.id
    assert second.id == stuck.id
    # loaded with what the dashboard renders
    assert first.product.name
  end

  test "aging keeps only the longest-waiting units" do
    for days <- 11..18 do
      "received" |> unit_fixture() |> set(received_on: Date.add(@today, -days))
    end

    assert Metrics.aging(@today) |> Enum.map(&elem(&1, 1)) == [18, 17, 16, 15, 14, 13]
  end
end
