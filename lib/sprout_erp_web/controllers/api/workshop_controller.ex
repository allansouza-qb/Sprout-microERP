defmodule SproutErpWeb.API.WorkshopController do
  use SproutErpWeb, :controller

  alias SproutErp.Inventory
  alias SproutErpWeb.API.Render

  @doc "The four workshop columns, oldest units first."
  def index(conn, _params) do
    board = Inventory.list_workshop()

    json(conn, %{
      data:
        for status <- ~w(received inspecting refurbishing ready) do
          %{status: status, units: board |> Map.get(status, []) |> Enum.map(&Render.unit/1)}
        end
    })
  end
end
