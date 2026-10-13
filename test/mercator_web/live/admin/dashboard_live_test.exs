defmodule MercatorWeb.Admin.DashboardLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Accounts.Role

  test "visitors are sent to sign in, customers are turned away", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin")

    assert {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
             conn |> log_in_user(user_fixture()) |> live(~p"/admin")
  end

  test "every staff role gets in", %{conn: conn} do
    for role <- Role.values() do
      assert {:ok, _view, _html} =
               build_conn() |> log_in_user(user_fixture(roles: [role])) |> live(~p"/admin")
    end

    assert conn
  end

  test "shows key figures and only the menu entries of the user's roles", %{conn: conn} do
    product_fixture()
    product_fixture(state: :draft)
    sales = user_fixture(roles: [:sales])

    {:ok, view, _html} = conn |> log_in_user(sales) |> live(~p"/admin")

    # sales only see active products; drafts are for product management
    assert has_element?(view, "#stat-products", "1")
    assert has_element?(view, "#admin-nav-dashboard")
    refute has_element?(view, "#admin-nav-users")

    {:ok, view, _html} =
      build_conn() |> log_in_user(user_fixture(roles: [:administrator])) |> live(~p"/admin")

    assert has_element?(view, "#stat-products", "2")
    assert has_element?(view, "#admin-nav-users")
    assert has_element?(view, "#shortcut-users")
  end

  test "the user menu links to the admin area for staff only", %{conn: conn} do
    html = conn |> log_in_user(user_fixture()) |> get(~p"/") |> html_response(200)
    refute html =~ ~s(id="admin-link")

    html =
      build_conn()
      |> log_in_user(user_fixture(roles: [:sales]))
      |> get(~p"/")
      |> html_response(200)

    assert html =~ ~s(id="admin-link")
  end
end
