defmodule MercatorWeb.Admin.SystemDashboardTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  test "visitors are sent to sign in" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), "/admin/system/home")
  end

  test "only administrators see the LiveDashboard" do
    assert {:error, {:redirect, %{to: "/"}}} =
             build_conn()
             |> log_in_user(user_fixture(roles: [:sales_manager]))
             |> live("/admin/system/home")

    conn = log_in_user(build_conn(), user_fixture(roles: [:administrator]))
    assert {:ok, _view, html} = live(conn, "/admin/system/home")
    assert html =~ "System information"
  end

  test "shows OS data and the database, leaves out the request logger and the environment" do
    conn = log_in_user(build_conn(), user_fixture(roles: [:administrator]))
    {:ok, view, _html} = live(conn, "/admin/system/home")

    assert has_element?(view, ~s(a[href="/admin/system/metrics"]))
    assert has_element?(view, ~s(a[href="/admin/system/os_mon"]))
    assert has_element?(view, ~s(a[href="/admin/system/ecto_stats"]))
    refute has_element?(view, ~s(a[href="/admin/system/request_logger"]))
    refute render(view) =~ "Environment"
  end

  test "the database page shows the repository's statistics (#134)" do
    conn = log_in_user(build_conn(), user_fixture(roles: [:administrator]))
    assert {:ok, _view, html} = live(conn, "/admin/system/ecto_stats")
    assert html =~ "Mercator.Repo"
  end

  test "is linked in the admin area for administrators only" do
    conn = log_in_user(build_conn(), user_fixture(roles: [:administrator]))
    {:ok, view, _html} = live(conn, ~p"/admin")
    assert has_element?(view, ~s(#admin-nav-system[href="/admin/system"][target="_blank"]))
    assert has_element?(view, ~s(#shortcut-system[href="/admin/system"][target="_blank"]))

    conn = log_in_user(build_conn(), user_fixture(roles: [:sales_manager]))
    {:ok, view, _html} = live(conn, ~p"/admin")
    refute has_element?(view, "#admin-nav-system")
  end
end
