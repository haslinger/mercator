defmodule MercatorWeb.HelpLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "visitors read the help without an account", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/help")

    assert has_element?(view, "#help h1", "Hilfe")
    assert has_element?(view, "#help-intro", "Beratung")
  end

  test "a chapter, in the visitor's language", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/help/index")
    assert has_element?(view, "#help-chapter h1", "Hilfe")
    assert has_element?(view, "#help-breadcrumbs a[href='/help']")

    conn = conn |> get(~p"/help?locale=en") |> recycle()
    {:ok, view, _html} = live(conn, ~p"/help/index")
    assert has_element?(view, "#help-chapter h1", "Help")
  end

  test "unknown chapters and other parts lead back to the help", %{conn: conn} do
    for path <- [~p"/help/nope", ~p"/help/payment-design"] do
      assert {:error, {:live_redirect, %{to: "/help"}}} = live(conn, path)
    end
  end

  test "search finds only the shop help", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/help")

    view |> element("#help-search") |> render_change(%{"q" => "Beratung"})
    assert_patch(view, ~p"/help?q=Beratung")
    assert has_element?(view, "#result-index")

    view |> element("#help-search") |> render_change(%{"q" => "Mollie"})
    assert has_element?(view, "#help-results", "Mollie")
    refute has_element?(view, "#help-results a")
  end

  test "the footer links to the help", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/basket")
    assert has_element?(view, ~s(#help-link[href="/help"]))
  end
end
