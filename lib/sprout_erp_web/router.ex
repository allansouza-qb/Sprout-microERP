defmodule SproutErpWeb.Router do
  use SproutErpWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {SproutErpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # There is no login. The session cookie only carries the CSRF token, which
  # the SPA sends on every write (x-csrf-token header).
  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  ## JSON API

  scope "/api", SproutErpWeb.API do
    pipe_through :api

    get "/dashboard", DashboardController, :show

    get "/lots", LotController, :index
    get "/lots/options", LotController, :options
    post "/lots", LotController, :create
    get "/lots/:id", LotController, :show

    get "/workshop", WorkshopController, :index

    get "/units", UnitController, :index
    get "/units/:id", UnitController, :show
    post "/units/:id/actions/:action", UnitController, :transition
    post "/units/:unit_id/work_items", WorkItemController, :create
    patch "/work_items/:id/toggle", WorkItemController, :toggle
    delete "/work_items/:id", WorkItemController, :delete

    get "/listings", ListingController, :index
    get "/sales", SaleController, :index

    match :*, "/*path", NotFoundController, :show
  end

  ## Downloads (plain browser requests, same filters as the screens)

  scope "/", SproutErpWeb do
    pipe_through :browser

    get "/export/inventory.csv", ExportController, :inventory
    get "/export/sales.csv", ExportController, :sales
  end

  ## Single-page app: every other path renders the Vue shell

  scope "/", SproutErpWeb do
    pipe_through :browser

    get "/*path", PageController, :index
  end
end
