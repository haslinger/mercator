defmodule MercatorWeb.AccountLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Accounts

  test "redirects visitors to the sign-in page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/account")
  end

  describe "signed in" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows the profile and password forms", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/account")

      assert has_element?(view, "#account-email", to_string(user.email))
      assert has_element?(view, "#profile-form")
      assert has_element?(view, "#password-form")
    end

    test "saves name, phone and language", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/account")

      view
      |> form("#profile-form",
        form: %{name: "Maria Huber", phone: "+43 1 234 56 78", locale: "en"}
      )
      |> render_submit()

      assert_redirect(view, ~p"/account?locale=en")

      updated = Accounts.get_user!(user.id, actor: user)
      assert updated.name == "Maria Huber"
      assert updated.phone == "+43 1 234 56 78"
      assert updated.locale == :en
    end

    test "shows validation errors for a too long name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account")

      html =
        view
        |> form("#profile-form", form: %{name: String.duplicate("x", 201)})
        |> render_change()

      assert html =~ "200"
    end

    test "changes the password and asks to sign in again", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/account")

      view
      |> form("#password-form",
        form: %{
          current_password: valid_password(),
          password: "a brand new password",
          password_confirmation: "a brand new password"
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/sign-in")

      assert {:ok, _} =
               AshAuthentication.Strategy.action(
                 AshAuthentication.Info.strategy!(Mercator.Accounts.User, :password),
                 :sign_in,
                 %{"email" => to_string(user.email), "password" => "a brand new password"}
               )
    end

    test "rejects a wrong current password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account")

      view
      |> form("#password-form",
        form: %{
          current_password: "not my password",
          password: "a brand new password",
          password_confirmation: "a brand new password"
        }
      )
      |> render_submit()

      assert has_element?(view, "#password-form")
      refute_redirected(view, ~p"/sign-in")
    end
  end
end
