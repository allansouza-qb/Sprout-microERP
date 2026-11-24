defmodule SproutErp.Purchasing.Lot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lots" do
    field :reference, :string
    field :purchased_on, :date
    field :total_cost_cents, :integer, default: 0
    field :notes, :string
    belongs_to :supplier, SproutErp.Purchasing.Supplier
    has_many :units, SproutErp.Inventory.Unit
    timestamps(type: :utc_datetime)
  end

  def changeset(lot, attrs) do
    lot
    |> cast(attrs, [:reference, :supplier_id, :purchased_on, :total_cost_cents, :notes])
    |> validate_required([:reference, :supplier_id, :purchased_on, :total_cost_cents])
    |> validate_number(:total_cost_cents, greater_than: 0)
    |> unique_constraint(:reference)
    |> foreign_key_constraint(:supplier_id)
  end
end
