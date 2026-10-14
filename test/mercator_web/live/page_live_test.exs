defmodule MercatorWeb.PageLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Content

  setup do
    editor = user_fixture(roles: [:contentmanager])

    about =
      Content.create_page!(
        %{
          title: %{"de" => "Über uns", "en" => "About us"},
          # own paths: page_test.exs runs in parallel and the paths are unique
          slug: "wir",
          blocks: [%{type: "text", text: %{"de" => "Seit **1928** im Wald."}}]
        },
        actor: editor
      )

    %{editor: editor, about: about}
  end

  test "visitors see published pages under /pages", %{conn: conn, editor: editor, about: about} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/pages/wir")

    Content.publish_page!(about, actor: editor)
    {:ok, view, _html} = live(conn, ~p"/pages/wir")

    assert has_element?(view, "#page-title", "Über uns")
    assert has_element?(view, "#page .markdown strong", "1928")
    refute has_element?(view, "#preview-banner")

    {:ok, view, _html} = live(conn, ~p"/pages/wir?locale=en")
    assert has_element?(view, "#page-title", "About us")
  end

  test "nested pages have nested paths", %{conn: conn, editor: editor, about: about} do
    Content.publish_page!(about, actor: editor)

    %{title: %{"de" => "Team"}, parent_id: about.id}
    |> Content.create_page!(actor: editor)
    |> Content.publish_page!(actor: editor)

    {:ok, view, _html} = live(conn, ~p"/pages/wir/team")
    assert has_element?(view, "#page-title", "Team")
  end

  test "visitors see the published version, editors can preview the working copy",
       %{conn: conn, editor: editor, about: about} do
    about
    |> Content.publish_page!(actor: editor)
    |> Content.update_page!(%{title: %{"de" => "Über uns – neu"}}, actor: editor)

    {:ok, view, _html} = live(conn, ~p"/pages/wir?preview=1")
    assert has_element?(view, "#page-title", "Über uns")
    refute has_element?(view, "#page-title", "neu")

    {:ok, view, _html} = live(log_in_user(conn, editor), ~p"/pages/wir?preview=1")
    assert has_element?(view, "#preview-banner")
    assert has_element?(view, "#page-title", "Über uns – neu")
  end

  test "editors can preview pages that were never published", %{conn: conn, editor: editor} do
    Content.create_page!(%{title: %{"de" => "Entwurf"}, slug: "skizze"}, actor: editor)

    {:ok, view, _html} = live(log_in_user(conn, editor), ~p"/pages/skizze?preview=1")
    assert has_element?(view, "#page-title", "Entwurf")
  end
end
