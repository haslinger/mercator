defmodule MercatorWeb.GtcLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Mercator.Sales
  alias Mercator.Seeds.BiberHolz

  test "shows a notice without terms", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/agb")

    assert has_element?(view, "#no-gtc")
  end

  test "shows the current terms with headings and paragraphs", %{conn: conn} do
    Ash.Seed.seed!(Sales.Gtc, BiberHolz.gtc())

    {:ok, view, _html} = live(conn, ~p"/agb")

    assert has_element?(view, "#gtc-version", "01.10.2026")
    assert has_element?(view, "#gtc h2", "1. Geltungsbereich")
    assert has_element?(view, "#gtc p", "Eigentum")
  end

  test "the footer links to the terms", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/warenkorb")

    assert has_element?(view, "#gtc-link")
  end
end
