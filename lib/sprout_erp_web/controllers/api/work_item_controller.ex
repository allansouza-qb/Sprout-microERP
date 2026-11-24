defmodule SproutErpWeb.API.WorkItemController do
  @moduledoc "Bench tasks of a unit. Every response is the refreshed unit."
  use SproutErpWeb, :controller

  alias SproutErp.{Inventory, Money}
  alias SproutErpWeb.API.Render

  action_fallback SproutErpWeb.API.FallbackController

  @minutes_error "Labor minutes must be a whole number (e.g. 30). Decimals like 2.5 are not accepted."

  def create(conn, %{"unit_id" => unit_id} = params) do
    unit = Inventory.get_unit!(unit_id)

    with {:ok, minutes} <- minutes(params["minutes"]),
         attrs = %{
           "description" => params["description"],
           "technician" => params["technician"],
           "parts_cents" => parts(params["parts"]),
           "labor_minutes" => minutes
         },
         {:ok, _item} <- Inventory.add_work_item(unit, attrs) do
      conn |> put_status(:created) |> render_unit(unit.id)
    end
  end

  def toggle(conn, %{"id" => id}) do
    with {:ok, item} <- Inventory.toggle_work_item(id) do
      render_unit(conn, item.unit_id)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, item} <- Inventory.delete_work_item(id) do
      render_unit(conn, item.unit_id)
    end
  end

  defp render_unit(conn, unit_id),
    do: json(conn, %{data: Render.unit_detail(Inventory.get_unit!(unit_id))})

  # Labor is stored as whole minutes; anything else is refused with a clear message.
  defp minutes(value) when value in [nil, ""], do: {:ok, 0}
  defp minutes(n) when is_integer(n) and n >= 0, do: {:ok, n}

  defp minutes(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} when n >= 0 -> {:ok, n}
      _ -> {:error, @minutes_error}
    end
  end

  defp minutes(_), do: {:error, @minutes_error}

  defp parts(value) when is_binary(value) or is_number(value), do: Money.to_cents(value) || 0
  defp parts(_), do: 0
end
