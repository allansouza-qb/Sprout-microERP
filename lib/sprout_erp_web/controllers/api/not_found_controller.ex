defmodule SproutErpWeb.API.NotFoundController do
  @moduledoc "Catch-all for unknown /api paths: JSON 404 instead of the SPA shell."
  use SproutErpWeb, :controller

  def show(conn, _params),
    do: SproutErpWeb.API.FallbackController.call(conn, {:error, :not_found})
end
