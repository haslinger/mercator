defmodule MercatorWeb.Admin.MediaLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Content

  setup %{conn: conn} do
    editor = user_fixture(roles: [:contentmanager])
    %{conn: log_in_user(conn, editor), editor: editor}
  end

  defp asset!(editor, attrs) do
    attrs
    |> Map.new()
    |> Map.merge(%{source_path: "test/fixtures/wood.jpg", original_filename: "wood.jpg"})
    |> Content.upload_asset!(actor: editor)
  end

  test "only content managers and administrators" do
    conn = log_in_user(build_conn(), user_fixture(roles: [:productmanager]))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/media")
  end

  test "uploads files with tags", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/media")
    assert has_element?(view, "#no-assets")

    image =
      file_input(view, "#upload-form", :files, [
        %{name: "stamm.jpg", content: File.read!("test/fixtures/wood.jpg"), type: "image/jpeg"}
      ])

    render_upload(image, "stamm.jpg")

    view |> form("#upload-form", %{"tags" => ""}) |> render_submit()
    assert has_element?(view, "#no-assets")

    view |> form("#upload-form", %{"tags" => "Wald, Stämme"}) |> render_submit()

    [asset] = Content.list_assets!()
    assert asset.tags == ["wald", "stämme"]
    assert asset.title == %{"de" => "stamm"}
    assert has_element?(view, "#asset-#{asset.id}", "stämme")
  end

  test "filters by text and tag", %{conn: conn, editor: editor} do
    oak = asset!(editor, title: %{"de" => "Eiche"}, tags: ["laubholz"])
    spruce = asset!(editor, title: %{"de" => "Fichte"}, tags: ["nadelholz"])

    {:ok, view, _html} = live(conn, ~p"/admin/media?tag=laubholz")
    assert has_element?(view, "#asset-#{oak.id}")
    refute has_element?(view, "#asset-#{spruce.id}")

    {:ok, view, _html} = live(conn, ~p"/admin/media?q=fichte")
    assert has_element?(view, "#asset-#{spruce.id}")
    refute has_element?(view, "#asset-#{oak.id}")
  end

  test "edits and deletes a file", %{conn: conn, editor: editor} do
    asset = asset!(editor, tags: ["wald"])
    {:ok, view, _html} = live(conn, ~p"/admin/media")

    view |> element("#asset-#{asset.id} button") |> render_click()

    assert has_element?(
             view,
             "#markdown-snippet[value*='/uploads/assets/#{asset.id}/large.webp']"
           )

    view
    |> form("#asset-form", form: %{alt: %{de: "Holzstapel"}, tags: "wald, stapel"})
    |> render_submit()

    asset = Content.get_asset!(asset.id)
    assert asset.alt["de"] == "Holzstapel"
    assert asset.tags == ["wald", "stapel"]

    view |> element("#asset-#{asset.id} button") |> render_click()
    view |> element("#delete-asset") |> render_click()
    refute has_element?(view, "#asset-#{asset.id}")
  end
end
