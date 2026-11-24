defmodule SproutErp.Inventory.Sale do
  @moduledoc """
  One Amazon order for a unit. The ledger keeps every sale: cancelling or
  returning changes `status` (and sets `closed_on`/`close_reason`), nothing is
  deleted. Only `completed` sales count as revenue.
  """
  use Ecto.Schema

  @statuses ~w(completed cancelled returned)

  schema "sales" do
    field :order_ref, :string
    field :price_cents, :integer
    field :fees_cents, :integer
    field :fees_estimated, :boolean, default: true
    field :sold_on, :date
    field :status, :string, default: "completed"
    field :closed_on, :date
    field :close_reason, :string
    belongs_to :unit, SproutErp.Inventory.Unit
    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def status_label("completed"), do: "Completed"
  def status_label("cancelled"), do: "Cancelled"
  def status_label("returned"), do: "Returned"
  def status_label(s), do: s
end
