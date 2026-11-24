defmodule SproutErpWeb.AppSocket do
  @moduledoc "Realtime socket for the SPA. It only carries \"something changed\" signals."
  use Phoenix.Socket

  channel "inventory", SproutErpWeb.InventoryChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
