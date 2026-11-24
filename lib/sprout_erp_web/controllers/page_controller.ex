defmodule SproutErpWeb.PageController do
  @moduledoc """
  Serves the single-page app. Every non-API path renders the same HTML shell;
  the Vue router decides which screen to show.
  """
  use SproutErpWeb, :controller

  alias SproutErp.{Clock, Inventory.Unit, Inventory.WorkItem, Catalog.Product}

  # A missing static file is a 404, not the app.
  def index(conn, %{"path" => [folder | _]}) when folder in ~w(assets images favicon.ico) do
    send_resp(conn, :not_found, "Not found")
  end

  def index(conn, _params) do
    render(conn, :index, boot: boot())
  end

  # Data the SPA needs before its first request: the company time zone and the
  # fixed vocabularies (stages, grades…), so labels and pricing factors have a
  # single source in the backend.
  defp boot do
    Jason.encode!(
      %{
        time_zone: Clock.time_zone(),
        statuses: for(s <- Unit.statuses(), do: %{key: s, label: Unit.status_label(s)}),
        grades:
          for g <- Unit.grades() do
            %{
              key: g,
              label: Unit.grade_label(g),
              short: Unit.grade_short(g),
              factor: Unit.grade_price_factor(g),
              help: Unit.grade_help(g)
            }
          end,
        categories: Product.categories(),
        technicians: WorkItem.technicians()
      },
      escape: :html_safe
    )
  end
end
