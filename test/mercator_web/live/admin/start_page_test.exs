defmodule MercatorWeb.Admin.StartPageTest do
  # not async: the key "home" is unique, like in the home page tests
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Content

  setup %{conn: conn} do
    editor = user_fixture(roles: [:contentmanager])
    %{conn: log_in_user(conn, editor), editor: editor}
  end

  defp published!(title, editor, attrs \\ %{}) do
    attrs
    |> Map.put(:title, %{"de" => title})
    |> Content.create_page!(actor: editor)
    |> Content.publish_page!(actor: editor)
  end

  describe "make_start_page" do
    test "moves the key home from the previous start page", %{editor: editor} do
      old = published!("Willkommen", editor, %{key: "home"})
      new = published!("Neu hier", editor)

      assert {:ok, %{key: "home"}} = Content.make_start_page(new, actor: editor)
      assert Content.get_page!(old.id, actor: editor).key == nil
      assert Content.get_published_page_by_key!("home").id == new.id
    end

    test "works without a previous start page", %{editor: editor} do
      page = published!("Neu hier", editor)
      assert {:ok, %{key: "home"}} = Content.make_start_page(page, actor: editor)
    end

    test "needs a published page and an editor", %{editor: editor} do
      draft = Content.create_page!(%{title: %{"de" => "Entwurf"}}, actor: editor)
      assert {:error, %Ash.Error.Invalid{}} = Content.make_start_page(draft, actor: editor)

      page = published!("Neu hier", editor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Content.make_start_page(page, actor: user_fixture())
    end
  end

  test "content managers use a page as the start page in the editor", %{
    conn: conn,
    editor: editor
  } do
    old = published!("Willkommen", editor, %{key: "home"})
    page = published!("Neu hier", editor)

    {:ok, view, _html} = live(conn, ~p"/admin/pages/#{old.id}")
    assert has_element?(view, "#start-page-badge")
    refute has_element?(view, "#make-start-page")

    {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")
    view |> element("#make-start-page") |> render_click()

    assert has_element?(view, "#start-page-badge")
    refute has_element?(view, "#make-start-page")

    {:ok, home, _html} = live(build_conn(), ~p"/")
    assert page_title(home) =~ "Neu hier"
  end
end
