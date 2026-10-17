defmodule MercatorWeb.RememberMeTest do
  # "Angemeldet bleiben": a remember me cookie (30 days) signs the user in
  # again when the browser session is gone, e.g. a closed phone app (PWA)
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  @form "#user-password-sign-in-with-password"
  @cookie "remember_me"

  # signs in on the sign-in page and follows the token exchange
  defp sign_in(conn, user, remember_me) do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    assert {:error, {:redirect, %{to: path}}} =
             view
             |> form(@form,
               user: %{
                 email: to_string(user.email),
                 password: valid_password(),
                 remember_me: to_string(remember_me)
               }
             )
             |> render_submit()

    get(conn, path)
  end

  # a new browser session that only has the cookie
  defp with_cookie(token), do: build_conn() |> put_req_cookie(@cookie, token)

  test "the sign-in form offers to stay signed in", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")
    assert has_element?(view, ~s(#{@form} input[type=checkbox][name="user[remember_me]"]))
  end

  test "staying signed in survives the end of the browser session", %{conn: conn} do
    user = user_fixture(roles: [:sales])
    conn = sign_in(conn, user, true)

    assert redirected_to(conn) == ~p"/admin/desk?available=true"
    assert %{value: token, max_age: max_age, http_only: true} = conn.resp_cookies[@cookie]
    assert max_age == 30 * 24 * 60 * 60

    conn = with_cookie(token) |> get(~p"/account")
    assert html_response(conn, 200)
    assert conn.assigns.current_user.id == user.id
  end

  test "without the checkbox, no cookie", %{conn: conn} do
    conn = sign_in(conn, user_fixture(), false)
    assert redirected_to(conn) == ~p"/"
    refute Map.has_key?(conn.resp_cookies, @cookie)
  end

  test "signing out deletes and revokes the cookie", %{conn: conn} do
    conn = sign_in(conn, user_fixture(), true)
    token = conn.resp_cookies[@cookie].value

    conn = conn |> recycle() |> put_req_cookie(@cookie, token) |> delete(~p"/sign-out")
    assert %{max_age: 0} = conn.resp_cookies[@cookie]

    conn = with_cookie(token) |> get(~p"/account")
    assert redirected_to(conn) =~ "/sign-in"
  end
end
