defmodule MercatorWeb.DemoLiveTest do
  # demo mode is a global switch
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  defp demo_mode(_context) do
    Application.put_env(:mercator, :demo_mode, true)
    on_exit(fn -> Application.delete_env(:mercator, :demo_mode) end)
  end

  # set_roles itself refuses public demo accounts in demo mode
  defp demo_sales do
    [email: "sales@mittenin.at"] |> user_fixture() |> Ash.Seed.update!(%{roles: [:sales]})
  end

  describe "outside demo mode" do
    test "the sign-in page has no demo logins and the shop no badge", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sign-in")
      assert has_element?(view, "#user-password-sign-in-with-password")
      refute has_element?(view, "#demo-logins")

      {:ok, view, _html} = live(conn, ~p"/")
      refute has_element?(view, "#demo-badge")
    end
  end

  describe "in demo mode" do
    setup :demo_mode

    test "the sign-in page lists the public demo logins", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sign-in")

      assert has_element?(view, "#user-password-sign-in-with-password")
      assert has_element?(view, "#demo-password", Mercator.Demo.password())
      assert has_element?(view, "#demo-login-sales", "sales@mittenin.at")
      assert has_element?(view, "#demo-fill-sales[data-email='sales@mittenin.at']")
      refute has_element?(view, "#demo-login-admin")
    end

    test "the register page only says that everything is reset", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      assert has_element?(view, "#demo-logins")
      refute has_element?(view, "#demo-login-list")
    end

    test "shop and admin area show the demo badge", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#demo-badge")

      admin = user_fixture(roles: [:administrator])
      {:ok, view, _html} = live(log_in_user(conn, admin), ~p"/admin")
      assert has_element?(view, "#admin-demo-badge")
    end

    test "a public demo account has no password form", %{conn: conn} do
      sales = demo_sales()
      {:ok, view, _html} = live(log_in_user(conn, sales), ~p"/account")

      assert has_element?(view, "#demo-password-note")
      refute has_element?(view, "#password-form")
    end

    test "other accounts keep their password form", %{conn: conn} do
      {:ok, view, _html} = live(log_in_user(conn, user_fixture()), ~p"/account")

      assert has_element?(view, "#password-form")
      refute has_element?(view, "#demo-password-note")
    end

    test "the roles of a public demo account cannot be edited", %{conn: conn} do
      admin = user_fixture(roles: [:administrator])
      sales = demo_sales()

      {:ok, view, _html} = live(log_in_user(conn, admin), ~p"/admin/users/#{sales.id}")

      assert has_element?(view, "#demo-roles-note")
      assert has_element?(view, "#roles-form fieldset[disabled]")
    end
  end
end
