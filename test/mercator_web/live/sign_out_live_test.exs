defmodule MercatorWeb.SignOutLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "the user menu signs out directly with DELETE", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query(~s(#sign-out-link[href="/sign-out"][data-method="delete"]))
           |> Enum.any?()
  end

  test "DELETE /sign-out signs out", %{conn: conn} do
    conn = delete(conn, ~p"/sign-out")

    assert redirected_to(conn) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Sie sind jetzt abgemeldet."

    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(recycle(conn), ~p"/account")
  end

  test "GET /sign-out asks in the user's language", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-out")

    assert has_element?(view, "#sign-out h2", "Abmelden")
    assert has_element?(view, "#sign-out p", "Möchten Sie sich abmelden?")
    assert has_element?(view, ~s(#sign-out-form[action="/sign-out"]))
    assert has_element?(view, ~s(#sign-out-form input[name="_method"][value="delete"]))

    {:ok, view, _html} = live(conn, ~p"/sign-out?locale=en")
    assert has_element?(view, "#sign-out h2", "Sign out")
  end
end
