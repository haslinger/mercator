defmodule MercatorWeb.Admin.UserAdminLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Accounts

  describe "access" do
    test "visitors are sent to the sign-in page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin/users")
    end

    test "users without the administrator role are turned away", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(roles: [:sales, :sales_manager]))

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
               live(conn, ~p"/admin/users")

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/users/#{user_fixture().id}")
    end

    test "the user menu links to user administration only for administrators", %{conn: conn} do
      html = conn |> log_in_user(user_fixture()) |> get(~p"/") |> html_response(200)
      refute html =~ ~s(id="admin-users-link")

      html =
        build_conn()
        |> log_in_user(user_fixture(roles: [:administrator]))
        |> get(~p"/")
        |> html_response(200)

      assert html =~ ~s(id="admin-users-link")
    end
  end

  describe "as administrator" do
    setup %{conn: conn} do
      admin = user_fixture(roles: [:administrator])
      %{conn: log_in_user(conn, admin), admin: admin}
    end

    test "lists all users", %{conn: conn, admin: admin} do
      customer = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(view, "#users-#{admin.id}")
      assert has_element?(view, "#users-#{customer.id}")
      assert has_element?(view, "#user-count", "2")
    end

    test "assigns roles to a user", %{conn: conn, admin: admin} do
      customer = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{customer.id}")

      view
      |> form("#roles-form", form: %{roles: ["", "sales", "contentmanager"]})
      |> render_submit()

      assert has_element?(view, "#role-sales[checked]")

      assert Enum.sort(Accounts.get_user!(customer.id, actor: admin).roles) ==
               [:contentmanager, :sales]
    end

    test "removes all roles from a user", %{conn: conn, admin: admin} do
      staff = user_fixture(roles: [:sales])

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{staff.id}")

      view |> form("#roles-form", form: %{roles: [""]}) |> render_submit()

      assert Accounts.get_user!(staff.id, actor: admin).roles == []
    end

    test "cannot remove the own administrator role", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, ~p"/admin/users/#{admin.id}")

      view |> form("#roles-form", form: %{roles: ["", "sales"]}) |> render_submit()

      assert has_element?(view, "#roles-error")
      assert Accounts.get_user!(admin.id, actor: admin).roles == [:administrator]
    end

    test "unknown user ids lead back to the list", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
               live(conn, ~p"/admin/users/#{Ash.UUID.generate()}")
    end
  end
end
