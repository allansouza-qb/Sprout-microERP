defmodule SproutErpWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use SproutErpWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint SproutErpWeb.Endpoint

      use SproutErpWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import SproutErpWeb.ConnCase
    end
  end

  setup tags do
    SproutErp.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Sends a JSON body, like the SPA does (values keep their JSON types)."
  defmacro json_request(conn, method, path, body \\ Macro.escape(%{})) do
    quote do
      unquote(conn)
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Phoenix.ConnTest.dispatch(
        @endpoint,
        unquote(method),
        unquote(path),
        Jason.encode!(unquote(body))
      )
    end
  end
end
