# Seeds a believable ~100 days of Sprout operations.
#   mix run priv/repo/seeds.exs   (or: mix ecto.reset)

alias SproutErp.Repo
alias SproutErp.Purchasing.{Supplier, Lot}
alias SproutErp.Catalog.Product
alias SproutErp.Inventory
alias SproutErp.Inventory.{Unit, WorkItem, Event, Sale}
import Ecto.Query

Logger.configure(level: :info)
:rand.seed(:exsss, {20, 26, 11})

today = SproutErp.Clock.today()
now = DateTime.utc_now(:second)

Repo.delete_all(Event)
Repo.delete_all(Sale)
Repo.delete_all(WorkItem)
Repo.delete_all(Unit)
Repo.delete_all(Lot)
Repo.delete_all(Product)
Repo.delete_all(Supplier)

suppliers =
  [
    {"Pacific Returns Co.", "retail_returns", "Ontario, CA"},
    {"Lakeshore Liquidation Group", "liquidator", "Chicago, IL"},
    {"Metro Trade-In Partners", "trade_in", "Newark, NJ"},
    {"Lone Star Surplus Auctions", "auction", "Dallas, TX"},
    {"Campus Buyback Network", "trade_in", "Columbus, OH"},
    {"Evergreen Asset Recovery", "liquidator", "Tacoma, WA"}
  ]
  |> Enum.map(fn {name, kind, loc} ->
    slug = name |> String.downcase() |> String.replace(~r/[^a-z]+/, "")

    Repo.insert!(%Supplier{
      name: name,
      kind: kind,
      location: loc,
      email: "sourcing@#{String.slice(slug, 0, 14)}.com"
    })
  end)

products =
  [
    {"iPhone 13 · 128GB", "Apple", "Smartphones", 59_900},
    {"iPhone 14 Pro · 256GB", "Apple", "Smartphones", 109_900},
    {"Galaxy S23 · 128GB", "Samsung", "Smartphones", 79_999},
    {"Pixel 8 · 128GB", "Google", "Smartphones", 69_900},
    {"MacBook Air 13\" M2", "Apple", "Laptops", 109_900},
    {"ThinkPad X1 Carbon Gen 10", "Lenovo", "Laptops", 164_900},
    {"XPS 13 9315", "Dell", "Laptops", 99_999},
    {"iPad 10th Gen · 64GB", "Apple", "Tablets", 34_900},
    {"iPad Air M1 · 64GB", "Apple", "Tablets", 59_900},
    {"Galaxy Tab S9 · 128GB", "Samsung", "Tablets", 79_999},
    {"AirPods Pro (2nd Gen)", "Apple", "Audio", 24_900},
    {"WH-1000XM5", "Sony", "Audio", 39_999},
    {"QuietComfort 45", "Bose", "Audio", 32_900},
    {"Switch OLED", "Nintendo", "Gaming", 34_999},
    {"Xbox Series S", "Microsoft", "Gaming", 29_999},
    {"Quest 3 · 128GB", "Meta", "Gaming", 49_999},
    {"Watch Series 8 · 45mm", "Apple", "Wearables", 42_900},
    {"Forerunner 255", "Garmin", "Wearables", 34_999},
    {"HERO11 Black", "GoPro", "Cameras", 39_999},
    {"ZV-1 Vlog Camera", "Sony", "Cameras", 74_999}
  ]
  |> Enum.map(fn {name, brand, cat, msrp} ->
    asin =
      "B0" <>
        for(_ <- 1..8, into: "", do: <<Enum.random(~c"ABCDEFGHJKLMNPQRSTUVWXYZ0123456789")>>)

    Repo.insert!(%Product{name: name, brand: brand, category: cat, msrp_cents: msrp, asin: asin})
  end)

by_cat = Enum.group_by(products, & &1.category)

bench = %{
  "Smartphones" => [
    {"Battery replacement", 1890, 35},
    {"Replace cracked back glass", 2450, 55},
    {"Swap charging port", 990, 30},
    {"Screen polish & new protector", 350, 15}
  ],
  "Laptops" => [
    {"Battery replacement", 6900, 45},
    {"Keyboard deep clean", 0, 25},
    {"Replace worn keycaps", 1800, 20},
    {"Thermal paste & fan service", 600, 35}
  ],
  "Tablets" => [
    {"Battery replacement", 3200, 40},
    {"Replace digitizer", 5400, 60},
    {"Port cleaning", 0, 10}
  ],
  "Audio" => [
    {"Replace ear cushions", 1490, 10},
    {"Replace ear tips & sanitize", 600, 10},
    {"Firmware reset & pairing test", 0, 15}
  ],
  "Gaming" => [
    {"Joy-Con drift repair", 1250, 30},
    {"Fan clean & re-paste", 450, 35},
    {"Replace face cushion", 1900, 10},
    {"Controller stick module", 1100, 25}
  ],
  "Wearables" => [
    {"Battery replacement", 2200, 40},
    {"Replace band", 900, 5},
    {"Sapphire glass polish", 300, 25}
  ],
  "Cameras" => [
    {"Lens cover replacement", 1600, 20},
    {"Sensor clean", 0, 30},
    {"Battery & door replacement", 2400, 15}
  ]
}

common = [
  {"Diagnostics & functional test", 0, 20},
  {"Certified data wipe", 0, 15},
  {"Cosmetic clean & repack", 250, 15}
]

techs = ["Maya R.", "Daniel K.", "Priya S.", "Luis M.", "Hannah O."]

pick_grade = fn ->
  r = :rand.uniform()

  cond do
    r < 0.15 -> "premium"
    r < 0.55 -> "excellent"
    r < 0.88 -> "good"
    true -> "acceptable"
  end
end

at = fn date, hour_from, hour_to ->
  # business hours in the company time zone, stored as UTC
  dt =
    SproutErp.Clock.utc_at(
      date,
      Time.new!(Enum.random(hour_from..hour_to), Enum.random(0..59), 0)
    )

  if DateTime.compare(dt, now) == :gt, do: DateTime.add(now, -Enum.random(4..170) * 60), else: dt
end

bins = fn -> Inventory.random_bin() end
# units were wiped above, so SKUs restart at SPR-10001 from the shared sequence
Inventory.reset_sku_sequence(10_000)

events = :ets.new(:seed_events, [:bag])

lot_days = [
  104,
  99,
  95,
  90,
  86,
  81,
  77,
  72,
  68,
  63,
  59,
  54,
  50,
  45,
  41,
  36,
  32,
  27,
  23,
  18,
  14,
  9,
  5,
  2
]

for {days_ago, idx} <- Enum.with_index(lot_days) do
  supplier = Enum.at(suppliers, rem(idx * 5 + 1, length(suppliers)))
  purchased_on = Date.add(today, -days_ago)
  cats = Enum.take_random(Map.keys(by_cat), Enum.random(2..3))
  lot_products = cats |> Enum.flat_map(&by_cat[&1]) |> Enum.take_random(Enum.random(3..5))
  growth = div(104 - days_ago, 45)
  items = for _ <- 1..(Enum.random(6..10) + growth), do: Enum.random(lot_products)

  costs = Enum.map(items, fn p -> round(p.msrp_cents * (0.27 + :rand.uniform() * 0.14)) end)
  total = Enum.sum(costs)

  month = Calendar.strftime(purchased_on, "%y%m")
  seq = Process.get({:lot_seq, month}, 0) + 1
  Process.put({:lot_seq, month}, seq)
  ref = "LOT-" <> month <> "-" <> String.pad_leading("#{seq}", 2, "0")

  lot =
    Repo.insert!(%Lot{
      reference: ref,
      supplier_id: supplier.id,
      purchased_on: purchased_on,
      total_cost_cents: total,
      notes:
        Enum.random([
          "Mixed customer returns, mostly boxed.",
          "Pallet from regional DC; some cosmetic wear.",
          "Trade-in batch, all units power on.",
          "Auction lot — untested, priced accordingly.",
          nil
        ])
    })

  received_on = Enum.min([Date.add(purchased_on, Enum.random(2..4)), today], Date)

  for {p, cost} <- Enum.zip(items, costs) do
    sku = "SPR-#{Inventory.reserve_sku_numbers(1)}"

    t_inspect = Date.add(received_on, Enum.random(0..2))
    t_grade = Date.add(t_inspect, Enum.random(1..2))
    t_ready = Date.add(t_grade, Enum.random(2..6))
    t_list = Date.add(t_ready, Enum.random(0..2))

    t_sold =
      Date.add(t_list, Enum.random([3, 4, 5, 6, 7, 8, 9, 11, 12, 14, 16, 19, 23, 28, 36, 45]))

    past? = fn d -> Date.compare(d, today) != :gt end
    received? = past?.(received_on)

    status =
      cond do
        not received? -> nil
        past?.(t_sold) -> "sold"
        past?.(t_list) -> "listed"
        past?.(t_ready) -> "ready"
        past?.(t_grade) -> "refurbishing"
        past?.(t_inspect) -> "inspecting"
        true -> "received"
      end

    if status do
      stage = Enum.find_index(Unit.statuses(), &(&1 == status))
      grade = if stage >= 2, do: pick_grade.(), else: nil
      unit0 = %Unit{product: p, grade: grade}
      list_price = if stage >= 4, do: Inventory.suggested_price_cents(unit0), else: nil

      sale_price =
        if status == "sold",
          do: round(list_price * (0.93 + :rand.uniform() * 0.07) / 100) * 100 - 1,
          else: nil

      unit =
        Repo.insert!(%Unit{
          sku: sku,
          serial: SproutErp.Purchasing.serial(),
          product_id: p.id,
          lot_id: lot.id,
          status: status,
          grade: grade,
          acquisition_cost_cents: cost,
          list_price_cents: list_price,
          sale_price_cents: sale_price,
          fees_cents:
            if(sale_price, do: Unit.estimated_fees_cents(%Unit{product: p}, sale_price)),
          order_ref: if(sale_price, do: Inventory.random_order_ref()),
          bin: if(stage >= 3, do: bins.()),
          received_on: received_on,
          listed_on: if(stage >= 4, do: t_list),
          sold_on: if(status == "sold", do: t_sold),
          inserted_at: at.(received_on, 8, 9),
          updated_at: now
        })

      # every sale also lives in the sales ledger
      if unit.status == "sold" do
        Repo.insert!(%Sale{
          unit_id: unit.id,
          order_ref: unit.order_ref,
          price_cents: unit.sale_price_cents,
          fees_cents: unit.fees_cents,
          fees_estimated: true,
          sold_on: unit.sold_on,
          status: "completed",
          inserted_at: now,
          updated_at: now
        })
      end

      :ets.insert(events, {unit.id, "received", "Received from #{ref}", at.(received_on, 8, 9)})

      if stage >= 1,
        do:
          :ets.insert(
            events,
            {unit.id, "inspection", "Inspection started", at.(t_inspect, 10, 11)}
          )

      # Bench work
      if stage >= 2 do
        :ets.insert(
          events,
          {unit.id, "graded", "Graded #{Unit.grade_label(grade)} · sent to the bench",
           at.(t_grade, 12, 12)}
        )

        tasks =
          Enum.take_random(bench[p.category], Enum.random(0..2)) ++
            Enum.take_random(common, Enum.random(1..2))

        tech = Enum.random(techs)

        bench_items =
          for {{desc, parts, mins}, i} <- Enum.with_index(tasks) do
            done =
              stage >= 3 or
                (status == "refurbishing" and i < length(tasks) - 1 and :rand.uniform() < 0.6)

            Repo.insert!(%WorkItem{
              unit_id: unit.id,
              description: desc,
              technician: tech,
              parts_cents: parts,
              labor_minutes: mins,
              done: done,
              inserted_at: at.(t_grade, 13, 16),
              updated_at: at.(t_grade, 13, 16)
            })
          end

        # only completed bench work counts in the unit's cost
        %{completed: refurb} = Inventory.bench_costs(bench_items)

        Repo.update!(Ecto.Changeset.change(unit, refurb_cost_cents: refurb))
      end

      if stage >= 3,
        do:
          :ets.insert(events, {unit.id, "qc", "Passed QC · ready to list", at.(t_ready, 14, 15)})

      if stage >= 4,
        do:
          :ets.insert(
            events,
            {unit.id, "listed",
             "Listed on Amazon Renewed at #{SproutErp.Money.format(list_price)}",
             at.(t_list, 16, 17)}
          )

      if stage >= 5,
        do:
          :ets.insert(
            events,
            {unit.id, "sold", "Sold on Amazon for #{SproutErp.Money.format(sale_price)}",
             at.(t_sold, 18, 22)}
          )
    end
  end
end

rows =
  :ets.tab2list(events)
  |> Enum.map(fn {uid, kind, msg, ts} ->
    %{unit_id: uid, kind: kind, message: msg, occurred_at: ts}
  end)

rows |> Enum.chunk_every(200) |> Enum.each(&Repo.insert_all(Event, &1))

# One cancelled and one returned order, so the sales ledger shows both flows.
case Repo.all(
       from u in Unit,
         where: u.status == "sold",
         order_by: [desc: u.sold_on, desc: u.id],
         limit: 2
     ) do
  [a, b] ->
    {:ok, _} =
      Inventory.cancel_sale(Inventory.get_unit!(a.id), "Buyer cancelled before shipment")

    {:ok, _} =
      Inventory.return_sale(
        Inventory.get_unit!(b.id),
        "Customer return: cosmetic expectations"
      )

  _ ->
    :ok
end

IO.puts(
  "Seeded #{Repo.aggregate(Unit, :count)} units across #{Repo.aggregate(Lot, :count)} lots and #{length(rows)} events."
)
