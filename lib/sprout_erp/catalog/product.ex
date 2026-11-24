defmodule SproutErp.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @categories ~w(Smartphones Laptops Tablets Audio Gaming Wearables Cameras)

  schema "products" do
    field :name, :string
    field :brand, :string
    field :category, :string
    field :asin, :string
    field :msrp_cents, :integer
    timestamps(type: :utc_datetime)
  end

  def categories, do: @categories

  def category_icon("Smartphones"), do: "hero-device-phone-mobile"
  def category_icon("Laptops"), do: "hero-computer-desktop"
  def category_icon("Tablets"), do: "hero-device-tablet"
  def category_icon("Audio"), do: "hero-musical-note"
  def category_icon("Gaming"), do: "hero-puzzle-piece"
  def category_icon("Wearables"), do: "hero-clock"
  def category_icon("Cameras"), do: "hero-camera"
  def category_icon(_), do: "hero-cube"

  @doc "Estimated FBA fulfillment fee per category, in cents."
  def fba_fee_cents("Laptops"), do: 985
  def fba_fee_cents("Gaming"), do: 760
  def fba_fee_cents("Tablets"), do: 590
  def fba_fee_cents("Cameras"), do: 540
  def fba_fee_cents(_), do: 445

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :brand, :category, :asin, :msrp_cents])
    |> validate_required([:name, :brand, :category, :msrp_cents])
    |> validate_inclusion(:category, @categories)
  end
end
