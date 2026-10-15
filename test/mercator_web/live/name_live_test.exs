defmodule MercatorWeb.NameLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Mercator.Accounts
  alias Mercator.Accounts.User
  alias MercatorWeb.LiveUserAuth

  require Ash.Query

  # like a user who signed up with a magic link: no name yet
  defp nameless_user do
    user =
      Ash.Seed.seed!(User, %{
        email: "magic#{System.unique_integer([:positive])}@example.com",
        confirmed_at: DateTime.utc_now()
      })

    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    Ash.Resource.put_metadata(user, :token, token)
  end

  describe "registration form" do
    test "asks for the name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      assert has_element?(
               view,
               ~s(#user-password-register-with-password input[name="user[name]"])
             )
    end

    test "registers with the name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      form =
        form(view, "#user-password-register-with-password",
          user: %{
            name: "Karl Luchs",
            email: "neu@example.com",
            password: "correct horse battery",
            password_confirmation: "correct horse battery"
          }
        )

      # the form registers and signs in with a token
      assert {:error, {:redirect, %{to: "/auth/user/password/sign_in_with_token?" <> _}}} =
               render_submit(form)

      assert %{name: "Karl Luchs"} =
               User
               |> Ash.Query.filter(email == "neu@example.com")
               |> Ash.read_one!(authorize?: false)
    end
  end

  describe "a signed-in user without a name" do
    setup %{conn: conn} do
      user = nameless_user()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "is sent to the name page from any page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/account/name"}}} = live(conn, ~p"/account/orders")
      assert {:error, {:redirect, %{to: "/account/name"}}} = live(conn, ~p"/")
    end

    test "enters the name and continues", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/account/name?return_to=/basket")

      view |> form("#name-form", form: %{name: ""}) |> render_submit()
      assert has_element?(view, "#name-form .text-error")

      view |> form("#name-form", form: %{name: "Lena Igel"}) |> render_submit()
      assert_redirect(view, ~p"/basket")

      assert Accounts.get_user!(user.id, actor: user).name == "Lena Igel"
      assert {:ok, _view, _html} = live(conn, ~p"/account/orders")
    end
  end

  test "users with a name and visitors are not stopped", %{conn: conn} do
    assert {:ok, _view, _html} = live(conn, ~p"/")

    conn = log_in_user(conn, Mercator.AccountsFixtures.user_fixture())
    assert {:ok, _view, _html} = live(conn, ~p"/account")
  end

  test "return_to stays within the shop" do
    assert LiveUserAuth.local_path("/checkout?offer=1") == "/checkout?offer=1"
    assert LiveUserAuth.local_path("//evil.example") == "/"
    assert LiveUserAuth.local_path("/\\evil.example") == "/"
    assert LiveUserAuth.local_path("https://evil.example") == "/"
    assert LiveUserAuth.local_path(nil) == "/"
  end
end
