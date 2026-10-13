defmodule MercatorWeb.PageControllerTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.AccountsFixtures

  test "GET / shows the start page with sign-in links for visitors", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert has?(document, "#home-hero")
    assert has?(document, "#sign-in-link")
    assert has?(document, "#register-link")
    refute has?(document, "#user-menu")
  end

  test "GET / shows the user menu for signed-in users", %{conn: conn} do
    user = user_fixture()

    html = conn |> log_in_user(user) |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert has?(document, "#user-menu")
    assert has?(document, "#sign-out-link")
    refute has?(document, "#sign-in-link")
  end

  defp has?(document, selector), do: document |> LazyHTML.query(selector) |> Enum.any?()
end
