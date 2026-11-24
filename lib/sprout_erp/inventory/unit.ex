defmodule SproutErp.Inventory.Unit do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(received inspecting refurbishing ready listed sold)
  @grades ~w(premium excellent good acceptable)

  schema "units" do
    field :sku, :string
    field :serial, :string
    field :status, :string, default: "received"
    field :grade, :string
    field :acquisition_cost_cents, :integer, default: 0
    field :refurb_cost_cents, :integer, default: 0
    field :list_price_cents, :integer
    field :sale_price_cents, :integer
    field :fees_cents, :integer
    # true while fees_cents holds Sprout's estimate rather than Amazon's actual charge
    field :fees_estimated, :boolean, default: true
    field :bin, :string
    field :order_ref, :string
    field :received_on, :date
    field :listed_on, :date
    field :sold_on, :date
    field :notes, :string
    field :lock_version, :integer, default: 1

    belongs_to :product, SproutErp.Catalog.Product
    belongs_to :lot, SproutErp.Purchasing.Lot
    has_many :work_items, SproutErp.Inventory.WorkItem, preload_order: [asc: :inserted_at]
    has_many :events, SproutErp.Inventory.Event, preload_order: [desc: :occurred_at, desc: :id]
    has_many :sales, SproutErp.Inventory.Sale, preload_order: [desc: :inserted_at, desc: :id]

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def grades, do: @grades

  def status_label("received"), do: "Received"
  def status_label("inspecting"), do: "Inspection"
  def status_label("refurbishing"), do: "Refurbishing"
  def status_label("ready"), do: "Ready to list"
  def status_label("listed"), do: "Listed"
  def status_label("sold"), do: "Sold"
  def status_label(s), do: s

  def grade_label("premium"), do: "Renewed Premium"
  def grade_label("excellent"), do: "Excellent"
  def grade_label("good"), do: "Good"
  def grade_label("acceptable"), do: "Acceptable"
  def grade_label(_), do: "Ungraded"

  def grade_short("premium"), do: "Premium"
  def grade_short(g), do: grade_label(g)

  @doc "What an inspector checks for each grade."
  def grade_help("premium"), do: "Like new — no visible wear, battery ≥ 90%."
  def grade_help("excellent"), do: "No imperfections visible at arm's length."
  def grade_help("good"), do: "Light scuffs visible at arm's length."
  def grade_help("acceptable"), do: "Visible wear; fully functional."

  @doc "Share of MSRP Sprout targets for each Amazon Renewed grade."
  def grade_price_factor("premium"), do: 0.86
  def grade_price_factor("excellent"), do: 0.76
  def grade_price_factor("good"), do: 0.66
  def grade_price_factor("acceptable"), do: 0.55
  def grade_price_factor(_), do: 0.6

  def changeset(unit, attrs) do
    unit
    |> cast(attrs, [
      :sku,
      :serial,
      :status,
      :grade,
      :acquisition_cost_cents,
      :refurb_cost_cents,
      :list_price_cents,
      :sale_price_cents,
      :fees_cents,
      :fees_estimated,
      :bin,
      :order_ref,
      :received_on,
      :listed_on,
      :sold_on,
      :notes,
      :product_id,
      :lot_id
    ])
    |> validate_required([:sku, :status, :product_id, :lot_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:grade, @grades)
    |> unique_constraint(:sku)
  end

  def total_cost_cents(%__MODULE__{} = u),
    do: (u.acquisition_cost_cents || 0) + (u.refurb_cost_cents || 0)

  @doc "Realized profit for sold units, projected profit (at list price) otherwise."
  def profit_cents(%__MODULE__{status: "sold"} = u),
    do: u.sale_price_cents - (u.fees_cents || 0) - total_cost_cents(u)

  def profit_cents(%__MODULE__{list_price_cents: p} = u) when is_integer(p),
    do: p - estimated_fees_cents(u, p) - total_cost_cents(u)

  def profit_cents(_), do: nil

  def estimated_fees_cents(%__MODULE__{product: %{category: cat}}, price_cents),
    do: round(price_cents * 0.08) + SproutErp.Catalog.Product.fba_fee_cents(cat)

  def estimated_fees_cents(_, price_cents), do: round(price_cents * 0.08) + 445

  def days_in_stock(%__MODULE__{received_on: nil}), do: 0

  def days_in_stock(%__MODULE__{received_on: r, sold_on: s}),
    do: Date.diff(s || SproutErp.Clock.today(), r)
end
