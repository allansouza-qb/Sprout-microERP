defmodule SproutErp.InventoryFixtures do
  @moduledoc "Test helpers that build suppliers, products, lots and units at a given stage."

  alias SproutErp.{Inventory, Purchasing, Repo}
  alias SproutErp.Catalog.Product
  alias SproutErp.Purchasing.Supplier

  defp unique, do: System.unique_integer([:positive])

  def supplier_fixture(attrs \\ %{}) do
    Repo.insert!(
      struct!(
        %Supplier{name: "Supplier #{unique()}", kind: "liquidator", location: "Austin, TX"},
        attrs
      )
    )
  end

  def product_fixture(attrs \\ %{}) do
    Repo.insert!(
      struct!(
        %Product{
          name: "Product #{unique()}",
          brand: "Acme",
          category: "Audio",
          msrp_cents: 30_000,
          asin: "B0TEST#{unique()}"
        },
        attrs
      )
    )
  end

  @doc "Receives a lot. `lines` is a list of `{product, quantity}`; cost defaults to $100 per unit."
  def lot_fixture(lines, attrs \\ %{}) do
    supplier = attrs[:supplier] || supplier_fixture()
    units = lines |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    {:ok, lot} =
      Purchasing.receive_lot(
        %{
          reference: "LOT-T-#{unique()}",
          supplier_id: supplier.id,
          purchased_on: attrs[:purchased_on] || SproutErp.Clock.today(),
          total_cost_cents: attrs[:total_cost_cents] || 10_000 * units
        },
        for({product, qty} <- lines, do: {product.id, qty})
      )

    Purchasing.get_lot!(lot.id)
  end

  @stages ~w(received inspecting refurbishing ready listed sold)

  @doc """
  One unit taken to `status`. Options: `:product`, `:grade` (default "good"),
  `:list_price` and `:sale_price` in cents, `:cost` (lot cost in cents).
  """
  def unit_fixture(status \\ "received", opts \\ []) do
    product = opts[:product] || product_fixture()
    lot = lot_fixture([{product, 1}], %{total_cost_cents: opts[:cost] || 10_000})
    [unit] = lot.units

    Enum.reduce(Enum.take(@stages, Enum.find_index(@stages, &(&1 == status)) + 1), unit, fn
      "received", unit -> unit
      "inspecting", unit -> step(Inventory.start_inspection(reload(unit)))
      "refurbishing", unit -> step(Inventory.assign_grade(reload(unit), opts[:grade] || "good"))
      "ready", unit -> step(Inventory.mark_ready(reload(unit)))
      "listed", unit -> step(Inventory.list_on_amazon(reload(unit), opts[:list_price]))
      "sold", unit -> step(Inventory.record_sale(reload(unit), opts[:sale_price]))
    end)
    |> reload()
  end

  def reload(unit), do: Inventory.get_unit!(unit.id)

  defp step({:ok, unit}), do: unit
end
