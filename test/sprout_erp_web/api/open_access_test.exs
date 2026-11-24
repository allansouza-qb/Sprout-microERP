defmodule SproutErpWeb.API.OpenAccessTest do
  @moduledoc "There is no login: the app, the API and the downloads answer any visitor."
  use SproutErpWeb.ConnCase, async: true

  test "the API answers without a session", %{conn: conn} do
    for path <- ~w(/api/dashboard /api/lots /api/workshop /api/units /api/listings /api/sales) do
      assert conn |> get(path) |> json_response(200)
    end
  end

  test "CSV downloads work without a session", %{conn: conn} do
    assert conn |> get(~p"/export/sales.csv") |> response(200) =~ "sold_on"
    assert conn |> get(~p"/export/inventory.csv") |> response(200) =~ "sku"
  end

  test "any app path serves the SPA shell, with no account in it", %{conn: conn} do
    for path <- ~w(/ /workshop /inventory/42 /login) do
      html = conn |> get(path) |> html_response(200)
      assert html =~ ~s(<div id="app"></div>)
      assert html =~ ~s("time_zone":)
      refute html =~ ~s("user")
      refute html =~ "password"
    end
  end

  test "there is no session endpoint", %{conn: conn} do
    body = %{email: "someone@sprout.test", password: "whatever"}

    assert %{"error" => "not_found"} =
             conn |> json_request(:post, "/api/session", body) |> json_response(404)
  end

  test "a missing static file is a 404, not the SPA shell", %{conn: conn} do
    assert conn |> get("/assets/js/missing.js") |> response(404) == "Not found"
  end

  test "unknown API paths answer 404 in JSON, not the SPA shell", %{conn: conn} do
    assert %{"error" => "not_found"} = conn |> get("/api/nope") |> json_response(404)

    unit = SproutErp.InventoryFixtures.unit_fixture()
    path = "/api/units/#{unit.id}/actions/explode"
    assert %{"error" => "not_found"} = conn |> json_request(:post, path) |> json_response(404)

    # a unit that does not exist
    assert_error_sent 404, fn -> get(conn, "/api/units/0") end
  end
end
