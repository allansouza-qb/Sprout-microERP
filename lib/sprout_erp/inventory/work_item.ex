defmodule SproutErp.Inventory.WorkItem do
  use Ecto.Schema
  import Ecto.Changeset

  @labor_rate_cents_per_minute 75
  @technicians ["Maya R.", "Daniel K.", "Priya S.", "Luis M.", "Hannah O."]

  schema "work_items" do
    field :description, :string
    field :technician, :string
    field :parts_cents, :integer, default: 0
    field :labor_minutes, :integer, default: 0
    field :done, :boolean, default: false
    belongs_to :unit, SproutErp.Inventory.Unit
    timestamps(type: :utc_datetime)
  end

  def labor_rate_cents_per_minute, do: @labor_rate_cents_per_minute

  @doc "Bench technicians (a fixed list in this PoC)."
  def technicians, do: @technicians

  def cost_cents(%__MODULE__{parts_cents: p, labor_minutes: m}),
    do: (p || 0) + (m || 0) * @labor_rate_cents_per_minute

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:description, :technician, :parts_cents, :labor_minutes, :done, :unit_id])
    |> validate_required([:description, :unit_id])
    |> validate_number(:parts_cents, greater_than_or_equal_to: 0)
    |> validate_number(:labor_minutes, greater_than_or_equal_to: 0)
  end
end
