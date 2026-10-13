defmodule MercatorWeb.LocaleTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.AccountsFixtures

  defp lang(conn) do
    conn.resp_body
    |> LazyHTML.from_document()
    |> LazyHTML.query("html")
    |> LazyHTML.attribute("lang")
    |> hd()
  end

  test "defaults to German", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert lang(conn) == "de"
    assert get_session(conn, "locale") == "de"
    assert conn.resp_body =~ "Anmelden"
  end

  test "uses a supported browser language", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept-language", "en-GB,en;q=0.9,de;q=0.8")
      |> get(~p"/")

    assert lang(conn) == "en"
    assert conn.resp_body =~ "Sign in"
  end

  test "ignores unsupported browser languages", %{conn: conn} do
    conn = conn |> put_req_header("accept-language", "fr-FR,fr;q=0.9") |> get(~p"/")

    assert lang(conn) == "de"
  end

  test "an explicit ?locale= choice is remembered for later requests", %{conn: conn} do
    conn = get(conn, ~p"/?locale=en")
    assert lang(conn) == "en"

    conn =
      conn
      |> recycle()
      |> put_req_header("accept-language", "de")
      |> get(~p"/")

    assert lang(conn) == "en"
  end

  test "unsupported ?locale= values are ignored", %{conn: conn} do
    conn = get(conn, ~p"/?locale=xx")

    assert lang(conn) == "de"
  end

  test "uses the signed-in user's preferred language", %{conn: conn} do
    user = user_fixture()
    user = Mercator.Accounts.update_profile!(user, %{locale: :en}, actor: user)

    conn = conn |> log_in_user(user) |> get(~p"/")

    assert lang(conn) == "en"
  end

  test "the sign-in page is translated", %{conn: conn} do
    assert conn |> get(~p"/sign-in") |> html_response(200) =~ "Passwort vergessen?"

    assert conn
           |> recycle()
           |> get(~p"/sign-in?locale=en")
           |> html_response(200) =~ "Forgot your password?"
  end
end
