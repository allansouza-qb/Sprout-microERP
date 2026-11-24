defmodule SproutErpWeb.InventoryChannelTest do
  @moduledoc "Realtime: every inventory change is announced to the open screens."
  use SproutErpWeb.ChannelCase, async: false

  import SproutErp.InventoryFixtures

  alias SproutErp.Inventory
  alias SproutErpWeb.AppSocket

  test "a change in inventory is pushed to every joined client" do
    unit = unit_fixture("received")

    {:ok, socket} = connect(AppSocket, %{})
    {:ok, _reply, _socket} = subscribe_and_join(socket, "inventory", %{})

    {:ok, _} = Inventory.start_inspection(unit)
    assert_push "changed", %{}
  end
end
