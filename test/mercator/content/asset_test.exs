defmodule Mercator.Content.AssetTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Content
  alias Mercator.Content.Asset

  setup do
    %{editor: user_fixture(roles: [:contentmanager])}
  end

  defp upload(editor, source, attrs \\ %{}) do
    attrs
    |> Map.new()
    |> Map.put_new(:tags, ["sägewerk"])
    |> Map.merge(%{source_path: source, original_filename: Path.basename(source)})
    |> Content.upload_asset(actor: editor)
  end

  test "images are stored as WebP in three sizes", %{editor: editor} do
    {:ok, asset} = upload(editor, "test/fixtures/wood.jpg", title: %{"de" => "Holz"})

    assert asset.kind == :image
    assert asset.width > 0

    for size <- ~w(wide large thumb) do
      assert File.exists?(Mercator.Uploads.path("assets/#{asset.id}/#{size}.webp"))
    end

    assert Asset.url(asset, :thumb) == "/uploads/assets/#{asset.id}/thumb.webp"
  end

  test "PDFs are stored under a clean name", %{editor: editor} do
    dir = Path.join(System.tmp_dir!(), "asset-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    source = Path.join(dir, "Preisliste Brennholz 2026.pdf")
    File.cp!("test/fixtures/sample.pdf", source)

    {:ok, asset} = upload(editor, source)

    assert asset.kind == :document
    assert asset.file_name == "preisliste-brennholz-2026.pdf"
    assert Asset.url(asset) == "/uploads/assets/#{asset.id}/preisliste-brennholz-2026.pdf"
  end

  test "other files are rejected", %{editor: editor} do
    assert {:error, _} = upload(editor, "mix.exs")
  end

  test "at least one tag; tags are normalised", %{editor: editor} do
    assert {:error, _} = upload(editor, "test/fixtures/wood.jpg", tags: [])

    {:ok, asset} = upload(editor, "test/fixtures/wood.jpg", tags: [" Wald, Holz ", "holz"])
    assert asset.tags == ["wald", "holz"]
    assert "wald" in Content.asset_tags()
  end

  test "search by text, tag and kind", %{editor: editor} do
    {:ok, oak} =
      upload(editor, "test/fixtures/wood.jpg", title: %{"de" => "Eichenstamm"}, tags: ["eiche"])

    {:ok, other} = upload(editor, "test/fixtures/wood.jpg", tags: ["fichte"])

    ids = fn input -> Content.search_assets!(input) |> Enum.map(& &1.id) end

    assert ids.(%{query: "eichen"}) == [oak.id]
    assert ids.(%{tag: "fichte"}) == [other.id]
    assert ids.(%{query: "eiche", kind: :document}) == []
  end

  test "assets used on a page cannot be deleted", %{editor: editor} do
    {:ok, asset} = upload(editor, "test/fixtures/wood.jpg")

    Content.create_page!(
      %{
        title: %{"de" => "Bilder"},
        blocks: [%{type: "text", text: %{"de" => "![x](#{Asset.url(asset)})"}}]
      },
      actor: editor
    )

    assert {:error, _} = Content.destroy_asset(asset, actor: editor)

    {:ok, unused} = upload(editor, "test/fixtures/wood.jpg")
    assert :ok = Content.destroy_asset(unused, actor: editor)
    refute File.exists?(Mercator.Uploads.path("assets/#{unused.id}"))
  end

  test "only content managers and administrators upload", %{editor: _editor} do
    assert {:error, %Ash.Error.Forbidden{}} = upload(user_fixture(), "test/fixtures/wood.jpg")
  end
end
