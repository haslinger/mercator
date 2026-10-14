defmodule Mercator.Content.PageTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Content
  alias Mercator.Content.Blocks

  doctest Mercator.Content

  setup do
    %{editor: user_fixture(roles: [:contentmanager])}
  end

  defp text(markdown), do: %{type: "text", text: %{"de" => markdown}}

  defp page!(attrs, editor) do
    attrs
    |> Map.new()
    |> Map.put_new(:title, %{"de" => "Über uns"})
    |> Content.create_page!(actor: editor)
  end

  describe "tree and paths" do
    test "paths follow the slugs of the ancestors", %{editor: editor} do
      about = page!(%{title: %{"de" => "Über uns"}}, editor)
      team = page!(%{title: %{"de" => "Unser Team"}, parent_id: about.id}, editor)

      assert about.path == "ueber-uns"
      assert team.path == "ueber-uns/unser-team"

      Content.update_page!(about, %{slug: "wir"}, actor: editor)
      assert Content.get_page!(team.id, actor: editor).path == "wir/unser-team"
    end

    test "moving a page below itself is rejected", %{editor: editor} do
      about = page!(%{}, editor)
      team = page!(%{title: %{"de" => "Team"}, parent_id: about.id}, editor)

      assert {:error, _} = Content.move_page(about, %{parent_id: team.id}, actor: editor)

      team = Content.move_page!(team, %{parent_id: nil}, actor: editor)
      assert team.path == "team"
    end

    test "paths are unique", %{editor: editor} do
      page!(%{}, editor)
      assert {:error, _} = Content.create_page(%{title: %{"de" => "Über uns"}}, actor: editor)
    end
  end

  describe "working copy and publishing (#90)" do
    test "visitors see only the published version", %{editor: editor} do
      page = page!(%{blocks: [text("Erste Fassung")]}, editor)

      assert {:error, _} = Content.get_published_page("ueber-uns")

      page = Content.publish_page!(page, actor: editor)
      assert page.state == :published
      refute page.changes_pending

      page = Content.update_page!(page, %{blocks: [text("Zweite Fassung")]}, actor: editor)
      assert page.changes_pending

      visible = Content.get_published_page!("ueber-uns")
      assert [%Ash.Union{value: %{text: %{"de" => "Erste Fassung"}}}] = visible.published.blocks

      Content.publish_page!(page, actor: editor)
      visible = Content.get_published_page!("ueber-uns")
      assert [%Ash.Union{value: %{text: %{"de" => "Zweite Fassung"}}}] = visible.published.blocks
    end

    test "discarding changes restores the published version", %{editor: editor} do
      page =
        page!(%{blocks: [text("Veröffentlicht")]}, editor) |> Content.publish_page!(actor: editor)

      page = Content.update_page!(page, %{title: %{"de" => "Neu"}}, actor: editor)

      page = Content.discard_page_changes!(page, actor: editor)
      assert page.title == %{"de" => "Über uns"}
      refute page.changes_pending
    end

    test "hidden pages stay hidden when published; archived pages are offline", %{editor: editor} do
      page =
        page!(%{}, editor)
        |> Content.publish_page!(actor: editor)
        |> Content.hide_page!(actor: editor)

      page = Content.publish_page!(page, actor: editor)
      assert page.state == :hidden
      assert {:ok, _} = Content.get_published_page("ueber-uns")

      page = Content.archive_page!(page, actor: editor)
      assert {:error, _} = Content.get_published_page("ueber-uns")

      assert Content.publish_page!(page, actor: editor).state == :published
    end

    test "only never-published pages can be deleted", %{editor: editor} do
      draft = page!(%{title: %{"de" => "Entwurf"}}, editor)
      assert :ok = Content.destroy_page(draft, actor: editor)

      page = page!(%{}, editor) |> Content.publish_page!(actor: editor)
      assert {:error, _} = Content.destroy_page(page, actor: editor)
    end
  end

  describe "history (#84)" do
    test "every publish is a version that can be restored", %{editor: editor} do
      page = page!(%{blocks: [text("Version 1")]}, editor) |> Content.publish_page!(actor: editor)

      page =
        page
        |> Content.update_page!(%{blocks: [text("Version 2")]}, actor: editor)
        |> Content.publish_page!(actor: editor)

      [first, second] =
        page
        |> Ash.load!(:paper_trail_versions, actor: editor)
        |> Map.fetch!(:paper_trail_versions)
        |> Enum.sort_by(& &1.version_inserted_at, DateTime)

      assert first.user_id == editor.id
      assert second.version_action_name == :publish

      page = Content.restore_page_version!(page, first.id, actor: editor)
      assert [%Ash.Union{value: %{text: %{"de" => "Version 1"}}}] = page.blocks
      assert page.changes_pending
      # still live: version 2 until the next publish
      assert [%Ash.Union{value: %{text: %{"de" => "Version 2"}}}] = page.published.blocks
    end
  end

  describe "editing helpers" do
    test "blocks are added, changed, moved and deleted in the working copy", %{editor: editor} do
      page = page!(%{blocks: [text("Eins")]}, editor)
      [%{"id" => first_id}] = Enum.map(page.blocks, &Blocks.to_input/1)
      second = Blocks.new("text") |> Map.put("text", %{"de" => "Zwei"})

      {:ok, page} =
        Content.update_page_blocks(page, &Blocks.put(&1, second), editor)

      {:ok, page} =
        Content.update_page_blocks(
          page,
          &Blocks.move(&1, second["id"], 0),
          editor
        )

      assert Enum.map(page.blocks, & &1.value.text["de"]) == ["Zwei", "Eins"]
      assert page.changes_pending

      {:ok, page} =
        Content.update_page_blocks(
          page,
          &Blocks.put(&1, %{"id" => first_id, "text" => %{"de" => "Eins!"}}),
          editor
        )

      {:ok, page} =
        Content.update_page_blocks(
          page,
          &Blocks.delete(&1, second["id"]),
          editor
        )

      assert Enum.map(page.blocks, & &1.value.text["de"]) == ["Eins!"]
    end

    test "pages are placed in the tree", %{editor: editor} do
      a = page!(%{title: %{"de" => "A"}}, editor)
      b = page!(%{title: %{"de" => "B"}}, editor)

      {:ok, b} = Content.place_page(b, nil, 0, editor)
      assert b.position == 1
      assert Content.get_page!(a.id, actor: editor).position == 2

      {:ok, b} = Content.place_page(b, a.id, 0, editor)
      assert b.path == "a/b"
    end
  end

  describe "permissions" do
    test "only content managers and administrators edit; visitors read published pages" do
      customer = user_fixture()

      assert {:error, %Ash.Error.Forbidden{}} =
               Content.create_page(%{title: %{"de" => "X"}}, actor: customer)

      admin = user_fixture(roles: [:administrator])
      draft = Content.create_page!(%{title: %{"de" => "Entwurf"}}, actor: admin)

      assert {:error, _} = Content.get_page(draft.id, actor: customer)
      assert {:error, _} = Content.get_page(draft.id)
    end
  end
end
