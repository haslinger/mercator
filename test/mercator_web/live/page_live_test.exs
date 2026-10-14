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

  describe "subpages" do
    setup %{editor: editor, about: about} do
      about = Content.publish_page!(about, actor: editor)

      child =
        %{
          title: %{"de" => "Unser Team"},
          parent_id: about.id,
          icon: "hero-user-group",
          seo_description: %{"de" => "Die Menschen hinter Biber Holz."},
          menu: :main
        }
        |> Content.create_page!(actor: editor)
        |> Content.publish_page!(actor: editor)

      %{about: about, child: child}
    end

    test "the parent links to its published subpages", %{
      conn: conn,
      editor: editor,
      about: about,
      child: child
    } do
      hidden =
        %{title: %{"de" => "Intern"}, parent_id: about.id}
        |> Content.create_page!(actor: editor)
        |> Content.publish_page!(actor: editor)
        |> Content.hide_page!(actor: editor)

      {:ok, view, _html} = live(conn, ~p"/pages/wir")

      assert has_element?(
               view,
               ~s(#subpage-#{child.id}[href="/pages/wir/unser-team"]),
               "Unser Team"
             )

      assert has_element?(view, "#subpage-#{child.id}", "Die Menschen hinter Biber Holz.")
      assert has_element?(view, "#subpage-#{child.id} .hero-user-group")
      refute has_element?(view, "#subpage-#{hidden.id}")
    end

    test "subpages show breadcrumbs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/pages/wir/unser-team")

      assert has_element?(view, ~s(.breadcrumbs a[href="/pages/wir"]), "Über uns")
      assert has_element?(view, ".breadcrumbs", "Unser Team")
    end

    test "subpages of an archived page are offline and leave the menu",
         %{conn: conn, editor: editor, about: about, child: child} do
      Content.archive_page!(about, actor: editor)

      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/pages/wir/unser-team")

      {:ok, view, _html} = live(conn, ~p"/")
      refute has_element?(view, "#nav-page-#{child.id}")
    end
  end

  describe "old addresses" do
    test "a renamed or moved page is still found at its old path (301)", %{
      conn: conn,
      editor: editor,
      about: about
    } do
      about = Content.publish_page!(about, actor: editor)

      child =
        %{title: %{"de" => "Anfahrt"}, parent_id: about.id}
        |> Content.create_page!(actor: editor)
        |> Content.publish_page!(actor: editor)

      Content.update_page!(about, %{slug: "wir-neu"}, actor: editor)

      conn1 = get(conn, "/pages/wir?locale=en")
      assert redirected_to(conn1, 301) == "/pages/wir-neu?locale=en"

      assert redirected_to(get(build_conn(), "/pages/wir/anfahrt"), 301) ==
               "/pages/wir-neu/anfahrt"

      # moved again: still one hop to the current address
      Content.move_page!(Content.get_page!(child.id, actor: editor), %{parent_id: nil},
        actor: editor
      )

      assert redirected_to(get(build_conn(), "/pages/wir/anfahrt"), 301) == "/pages/anfahrt"
      assert redirected_to(get(build_conn(), "/pages/wir-neu/anfahrt"), 301) == "/pages/anfahrt"
    end

    test "a new page at an old path takes it over", %{conn: conn, editor: editor, about: about} do
      Content.update_page!(about, %{slug: "wir-alt"}, actor: editor)

      %{title: %{"de" => "Wir"}, slug: "wir"}
      |> Content.create_page!(actor: editor)
      |> Content.publish_page!(actor: editor)

      {:ok, view, _html} = live(conn, ~p"/pages/wir")
      assert has_element?(view, "#page-title", "Wir")
    end
  end
end
