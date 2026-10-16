defmodule MercatorWeb.AuthControllerTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.AccountsFixtures

  alias MercatorWeb.AuthController

  defp sign_in(conn, user, session \\ %{}) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Plug.Test.init_test_session(session)
    |> bypass_through(MercatorWeb.Router, [:browser])
    |> get(~p"/")
    |> AuthController.success(
      {:password, :sign_in},
      Ash.Resource.put_metadata(user, :token, token),
      token
    )
  end

  describe "start page after the sign-in" do
    test "customers go to the shop", %{conn: conn} do
      assert redirected_to(sign_in(conn, user_fixture())) == ~p"/"
    end

    test "consultants go to the desk, available", %{conn: conn} do
      for roles <- [[:sales], [:sales_manager]] do
        assert redirected_to(sign_in(conn, user_fixture(roles: roles))) ==
                 ~p"/admin/desk?available=true"
      end
    end

    test "administrators go to the back office", %{conn: conn} do
      assert redirected_to(sign_in(conn, user_fixture(roles: [:administrator]))) == ~p"/admin"
    end

    test "the desk wins for administrators who are consultants too", %{conn: conn} do
      user = user_fixture(roles: [:administrator, :sales])
      assert redirected_to(sign_in(conn, user)) == ~p"/admin/desk?available=true"
    end

    test "other staff go to the shop", %{conn: conn} do
      assert redirected_to(sign_in(conn, user_fixture(roles: [:contentmanager]))) == ~p"/"
    end

    test "a page that asked for the sign-in wins", %{conn: conn} do
      user = user_fixture(roles: [:administrator])
      assert redirected_to(sign_in(conn, user, %{return_to: "/checkout"})) == ~p"/checkout"
    end
  end
end
