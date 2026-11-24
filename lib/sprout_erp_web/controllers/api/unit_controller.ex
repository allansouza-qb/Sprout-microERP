defmodule SproutErpWeb.API.UnitController do
  use SproutErpWeb, :controller

  alias SproutErp.{Inventory, Money}
  alias SproutErp.Inventory.Unit
  alias SproutErpWeb.API.Render

  action_fallback SproutErpWeb.API.FallbackController

  def index(conn, params) do
    units =
      Inventory.list_units(
        status: params["status"],
        category: params["category"],
        search: params["q"]
      )

    json(conn, %{
      data: %{units: Enum.map(units, &Render.unit/1), counts: Inventory.count_by_status()}
    })
  end

  def show(conn, %{"id" => id}) do
    json(conn, %{data: Render.unit_detail(Inventory.get_unit!(id))})
  end

  @doc """
  Moves a unit along the pipeline: `POST /api/units/:id/actions/:action`.

  The body carries `version` (the `lock_version` the client is looking at), so
  an action taken on an outdated screen is refused with 409 instead of being
  applied twice. Depending on the action it also takes `grade`, `price`
  (dollars) or `reason`.
  """
  def transition(conn, %{"id" => id, "action" => action} = params) do
    unit = id |> Inventory.get_unit!() |> Inventory.with_seen_version(version(params["version"]))

    with {:ok, _} <- run(action, unit, params) do
      json(conn, %{
        data: Render.unit_detail(Inventory.get_unit!(id)),
        message: done(action, params)
      })
    end
  end

  defp version(v) when is_integer(v), do: Integer.to_string(v)
  defp version(v), do: v

  defp run("start_inspection", unit, _params), do: Inventory.start_inspection(unit)

  defp run("grade", unit, %{"grade" => grade}) when is_binary(grade),
    do: Inventory.assign_grade(unit, grade)

  defp run("grade", _unit, _params), do: {:error, "Choose a grade"}
  defp run("mark_ready", unit, _params), do: Inventory.mark_ready(unit)

  # Without a price the unit is listed at the suggested price for its grade.
  defp run("list", unit, params) do
    case price(params) do
      :none -> Inventory.list_on_amazon(unit)
      {:ok, cents} -> Inventory.list_on_amazon(unit, cents)
      :error -> {:error, "Enter a valid price"}
    end
  end

  defp run("reprice", unit, params) do
    case price(params) do
      {:ok, cents} -> Inventory.update_list_price(unit, cents)
      _ -> Inventory.update_list_price(unit, 0)
    end
  end

  # Without a price the sale is recorded at the list price.
  defp run("sell", unit, params) do
    case price(params) do
      :none -> Inventory.record_sale(unit)
      {:ok, cents} -> Inventory.record_sale(unit, cents)
      :error -> {:error, "Enter a valid sale price"}
    end
  end

  defp run("cancel_sale", unit, params), do: Inventory.cancel_sale(unit, reason(params))

  defp run("return_sale", unit, params), do: Inventory.return_sale(unit, reason(params))

  defp run(_unknown, _unit, _params), do: {:error, :not_found}

  defp price(%{"price" => value}) when is_binary(value) or is_number(value) do
    case Money.to_cents(value) do
      cents when is_integer(cents) and cents > 0 -> {:ok, cents}
      _ -> :error
    end
  end

  defp price(%{"price" => _}), do: :error
  defp price(_params), do: :none

  defp reason(%{"reason" => reason}) when is_binary(reason), do: reason
  defp reason(_params), do: nil

  defp done("start_inspection", _), do: "Inspection started"

  defp done("grade", %{"grade" => g}),
    do: "Graded #{Unit.grade_label(g)} — unit sent to the bench"

  defp done("mark_ready", _), do: "QC passed — ready to list"
  defp done("list", _), do: "Listed on Amazon Renewed"
  defp done("reprice", _), do: "Listing repriced"
  defp done("sell", _), do: "Sale recorded"
  defp done("cancel_sale", _), do: "Order cancelled — unit is back on Amazon"
  defp done("return_sale", _), do: "Return recorded — unit is back in receiving"
end
