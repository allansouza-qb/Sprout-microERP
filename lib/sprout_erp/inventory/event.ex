defmodule SproutErp.Inventory.Event do
  use Ecto.Schema

  schema "events" do
    field :kind, :string
    field :message, :string
    field :occurred_at, :utc_datetime
    belongs_to :unit, SproutErp.Inventory.Unit
  end
end
