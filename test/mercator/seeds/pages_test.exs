defmodule Mercator.Seeds.PagesTest do
  # not async: the demo pages use common paths like "ueber-uns" (unique)
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Mercator.Content
  alias Mercator.Seeds.Pages

  test "creates the published demo pages with start page, menus and footer", %{conn: conn} do
    Pages.run()

    for key <- ~w(home contact imprint privacy) do
      assert {:ok, %{state: :published}} = Content.get_published_page_by_key(key)
    end

    assert {:ok, %{kind: :shared}} =
             Content.get_page_by_path("oeffnungszeiten", authorize?: false)

    assert Content.list_menu_pages!(:main) |> Enum.map(& &1.path) ==
             ~w(ueber-uns saegewerk faq kontakt)

    assert Content.list_menu_pages!(:footer) |> Enum.map(& &1.path) == ~w(impressum datenschutz)

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#page .hero h2", "Holz aus dem Waldviertel")
    assert has_element?(view, ~s(#shop-nav a[href="/pages/kontakt"]))

    {:ok, view, _html} = live(conn, ~p"/pages/kontakt")
    assert has_element?(view, "#page", "Montag bis Freitag")
    assert has_element?(view, "#page form [name='form[message]']")
  end

  test "imprint and privacy policy name the operator; the cookie notice links the policy",
       %{conn: conn} do
    Pages.run()

    {:ok, view, _html} = live(conn, ~p"/pages/impressum")
    assert has_element?(view, "#page", "Informatom EDV-Dienstleistungen e.U.")
    assert has_element?(view, "#page", "FN 357693 w")
    assert has_element?(view, "#page", "erfundenes Unternehmen")

    {:ok, view, _html} = live(conn, ~p"/pages/datenschutz")
    assert has_element?(view, "#page table td code", "_mercator_key")
    assert has_element?(view, "#page", "Datenschutzbehörde")

    # only necessary cookies: a notice, no consent; the hook shows it
    assert has_element?(view, "#cookie-notice[phx-hook].hidden")
    assert has_element?(view, ~s(#cookie-notice-more[href="/pages/datenschutz"]))

    {:ok, view, _html} = live(conn, ~p"/pages/datenschutz?locale=en")
    assert has_element?(view, "#page", "strictly necessary cookies")
  end

  test "is idempotent and keeps pages changed by editors" do
    Pages.run()
    {:ok, about} = Content.get_page_by_path("ueber-uns", authorize?: false)
    Content.update_page!(about, %{title: %{"de" => "Wir"}}, authorize?: false)

    Pages.run()

    assert length(Content.list_pages!(authorize?: false)) == 8
    assert Content.get_page!(about.id, authorize?: false).title == %{"de" => "Wir"}
  end
end
