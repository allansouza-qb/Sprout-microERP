defmodule SproutErpWeb.API.FallbackController do
  @moduledoc """
  Translates context results into HTTP responses for the JSON API:

    * `{:error, :stale}` → 409: the record changed since the client loaded it
    * `{:error, "message"}` / `{:error, %Ecto.Changeset{}}` → 422
    * `{:error, :not_found}` → 404
  """
  use SproutErpWeb, :controller

  @stale_message "This item was already updated"

  def stale_message, do: @stale_message

  def call(conn, {:error, :stale}) do
    conn |> put_status(:conflict) |> json(%{error: "stale", message: @stale_message})
  end

  def call(conn, {:error, message}) when is_binary(message) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid", message: message})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors = Ecto.Changeset.traverse_errors(changeset, &translate/1)

    messages =
      for {field, [first | _]} <- Enum.sort(errors), do: "#{humanize(field)} #{first}"

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "invalid",
      message: List.first(messages) || "Invalid data",
      messages: messages,
      errors: errors
    })
  end

  def call(conn, {:error, :not_found}) do
    conn |> put_status(:not_found) |> json(%{error: "not_found", message: "Not found"})
  end

  defp translate({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  # :total_cost_cents -> "Total cost", :supplier_id -> "Supplier"; errors placed
  # on :base/:lines describe the whole request and read on their own.
  defp humanize(field) when field in [:base, :lines], do: "Lot:"

  defp humanize(field) do
    field
    |> to_string()
    |> String.replace(~r/_(cents|id)$/, "")
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
