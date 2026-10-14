defmodule MercatorWeb.HomeLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  test "GET / shows the start page with sign-in links for visitors", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert has?(document, "#home-hero")
    assert has?(document, ~s(#back-button[aria-label="Zurück"]))
    assert has?(document, "#sign-in-link")
    assert has?(document, "#register-link")
    refute has?(document, "#user-menu")
  end

  test "GET / shows the user menu for signed-in users", %{conn: conn} do
    user = user_fixture()

    html = conn |> log_in_user(user) |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert has?(document, "#user-menu")
    assert has?(document, "#sign-out-link")
    refute has?(document, "#sign-in-link")
  end

  test "GET / offers language and theme in a menu for phones (#72)", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert has?(document, ~s(#locale-switch a[href="?locale=en"]))
    assert has?(document, ~s(#more-menu #more-locale-switch a[href="?locale=en"]))
    assert has?(document, ~s(#more-menu button[data-phx-theme="dark"]))
  end

  defp has?(document, selector), do: document |> LazyHTML.query(selector) |> Enum.any?()

  describe "start page from the CMS (#81)" do
    setup do
      editor = user_fixture(roles: [:contentmanager])

      home =
        Mercator.Content.create_page!(
          %{
            title: %{"de" => "Willkommen"},
            slug: "start",
            key: "home",
            blocks: [
              %{type: "hero", headline: %{"de" => "Holz aus dem Waldviertel"}},
              %{type: "text", text: %{"de" => "Seit 1928."}}
            ]
          },
          actor: editor
        )

      %{editor: editor, home: home}
    end

    test "the published home page replaces the default start page", %{
      conn: conn,
      editor: editor,
      home: home
    } do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#home-hero")

      Mercator.Content.publish_page!(home, actor: editor)
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#home-hero")
      assert has_element?(view, "#page .hero h2", "Holz aus dem Waldviertel")
      # the hero is the headline; the title stays for screen readers
      assert has_element?(view, "#page-title.sr-only", "Willkommen")
    end

    test "editors preview the home page", %{conn: conn, editor: editor} do
      {:ok, view, _html} = live(log_in_user(conn, editor), ~p"/?preview=1")
      assert has_element?(view, "#preview-banner")
      assert has_element?(view, "#page", "Seit 1928.")
    end
  end
end
