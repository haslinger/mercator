defmodule MercatorWeb.Admin.PageAdminLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Content

  setup %{conn: conn} do
    editor = user_fixture(roles: [:contentmanager])
    %{conn: log_in_user(conn, editor), editor: editor}
  end

  defp page!(editor, attrs \\ %{}) do
    attrs
    |> Map.new()
    |> Map.put_new(:title, %{"de" => "Sägewerk"})
    |> Content.create_page!(actor: editor)
  end

  describe "access" do
    test "only content managers and administrators" do
      for roles <- [[], [:sales], [:productmanager]] do
        conn = log_in_user(build_conn(), user_fixture(roles: roles))
        assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/pages")
      end

      conn = log_in_user(build_conn(), user_fixture(roles: [:administrator]))
      assert {:ok, _view, _html} = live(conn, ~p"/admin/pages")
    end

    test "the sidebar links to the pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")
      assert has_element?(view, ~s(#admin-nav a[href="/admin/pages"]))
    end
  end

  describe "page tree" do
    test "creates a page and opens its editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/pages")
      assert has_element?(view, "#no-pages")

      view |> element("#new-page") |> render_click()

      {:ok, _editor, html} =
        view
        |> form("#page-form", form: %{title: %{de: "Über uns", en: "About us"}})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Über uns"

      assert {:ok, %{path: "ueber-uns", state: :draft}} =
               Content.get_page_by_path("ueber-uns", authorize?: false)
    end

    test "shows the tree, moves and deletes drafts", %{conn: conn, editor: editor} do
      about = page!(editor, title: %{"de" => "Über uns"})
      team = page!(editor, title: %{"de" => "Team"})

      {:ok, view, _html} = live(conn, ~p"/admin/pages")
      assert has_element?(view, "#page-#{about.id}", "/pages/ueber-uns")

      render_hook(view, "move", %{"id" => team.id, "parent_id" => about.id, "index" => 0})
      assert has_element?(view, "#page-#{team.id}", "/pages/ueber-uns/team")

      render_hook(view, "move", %{"id" => team.id, "parent_id" => nil, "index" => 0})
      view |> element("#delete-#{team.id}") |> render_click()
      refute has_element?(view, "#page-#{team.id}")
    end
  end

  describe "page editor" do
    test "adds, edits, reorders and deletes blocks", %{conn: conn, editor: editor} do
      page = page!(editor)
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")
      assert has_element?(view, "#no-blocks")

      view |> element("#add-block-text") |> render_click()
      assert has_element?(view, "#block-modal [phx-hook=MarkdownEditor]")

      view
      |> form("#block-form", block: %{text: %{de: "## Seit 1928\nim Waldviertel"}})
      |> render_submit()

      refute has_element?(view, "#block-modal")
      assert has_element?(view, "#blocks h2", "Seit 1928")
      assert has_element?(view, "#changes-pending")

      view |> element("#add-block-text") |> render_click()
      view |> form("#block-form", block: %{text: %{de: "Zweiter Block"}}) |> render_submit()

      [first, second] = Content.get_page!(page.id, actor: editor).blocks
      render_hook(view, "reorder_blocks", %{"id" => second.value.id, "index" => 0})

      assert [%{value: %{text: %{"de" => "Zweiter Block"}}}, _] =
               Content.get_page!(page.id, actor: editor).blocks

      view |> element("#edit-#{first.value.id}") |> render_click()
      view |> form("#block-form", block: %{text: %{de: "Geändert"}}) |> render_submit()
      assert has_element?(view, "#edit-block-#{first.value.id}", "Geändert")

      view |> element("#delete-#{second.value.id}") |> render_click()
      refute has_element?(view, "#edit-block-#{second.value.id}")
    end

    test "saves settings, publishes, archives; history and restore", %{conn: conn, editor: editor} do
      page = page!(editor, blocks: [%{type: "text", text: %{"de" => "Erste Fassung"}}])
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")

      view
      |> form("#settings-form", form: %{slug: "saegewerk", menu: "main"})
      |> render_submit()

      assert Content.get_page!(page.id, actor: editor).menu == :main

      view |> element("#publish") |> render_click()
      assert has_element?(view, "#page-state", "Veröffentlicht")
      refute has_element?(view, "#publish")
      assert has_element?(view, "#history li", "1")

      view |> element("#add-block-text") |> render_click()
      view |> form("#block-form", block: %{text: %{de: "Zweite Fassung"}}) |> render_submit()
      assert has_element?(view, "#discard")

      [version] =
        Content.get_page!(page.id, actor: editor)
        |> Ash.load!(:paper_trail_versions, actor: editor)
        |> Map.fetch!(:paper_trail_versions)

      view |> element("#restore-#{version.id}") |> render_click()
      assert Content.get_page!(page.id, actor: editor).blocks |> length() == 1

      view |> element("#hide") |> render_click()
      assert has_element?(view, "#page-state", "Ausgeblendet")

      view |> element("#archive") |> render_click()
      assert has_element?(view, "#page-state", "Archiviert")
      assert {:error, _} = Content.get_published_page("saegewerk")
    end
  end
end
