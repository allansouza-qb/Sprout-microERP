defmodule SproutErpWeb.Router do
  use SproutErpWeb, :router

  # There is no login. The session cookie only carries the CSRF token, which
  # the SPA sends on every write (x-csrf-token header).
  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
end
