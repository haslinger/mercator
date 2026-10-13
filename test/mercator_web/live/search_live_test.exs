defmodule MercatorWeb.SearchLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.CatalogFixtures

  setup do
    %{
      product:
        product_fixture(title: %{"de" => "Terrassendiele Lärche", "en" => "Decking board larch"})
    }
  end

  test "searching updates the URL and shows the results", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/suche")
    assert has_element?(view, "#no-results")

    view |> element("#search-form") |> render_change(%{"q" => "lärche"})

    assert_patch(view, ~p"/suche?q=l%C3%A4rche")
    assert has_element?(view, "#result-#{product.id}")
    assert has_element?(view, "#result-count", "1")
  end

  test "a search URL can be opened directly", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/suche?q=decking")

    assert has_element?(view, "#result-#{product.id}")
  end

  test "no results", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/suche?q=gibtsnicht")

    assert has_element?(view, "#no-results")
  end

  test "the navbar has a search form", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200) =~ ~s(id="navbar-search")
  end
end
