defmodule SproutErpWeb.InventoryChannel do
  @moduledoc """
  Tells every open screen that inventory changed, so it can refetch.

  It carries no data on purpose: the API stays the single place data comes from.
  """
  use SproutErpWeb, :channel

  @impl true
  def join("inventory", _payload, socket) do
    SproutErp.Inventory.subscribe()
    {:ok, socket}
  end

  @impl true
  def handle_info(:inventory_changed, socket) do
    push(socket, "changed", %{})
    {:noreply, socket}
  end
end
