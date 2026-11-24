defmodule SproutErp.Purchasing.Supplier do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(liquidator auction trade_in retail_returns)

  schema "suppliers" do
    field :name, :string
    field :kind, :string
    field :location, :string
    field :email, :string
    has_many :lots, SproutErp.Purchasing.Lot
    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds

  def kind_label("liquidator"), do: "Liquidator"
  def kind_label("auction"), do: "Auction house"
  def kind_label("trade_in"), do: "Trade-in partner"
  def kind_label("retail_returns"), do: "Retail returns"
  def kind_label(other), do: other

  def changeset(supplier, attrs) do
    supplier
    |> cast(attrs, [:name, :kind, :location, :email])
    |> validate_required([:name, :kind])
    |> validate_inclusion(:kind, @kinds)
  end
end
