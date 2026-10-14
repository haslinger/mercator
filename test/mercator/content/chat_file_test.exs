defmodule Mercator.Content.ChatFileTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Content
  alias Mercator.Content.{Asset, FileTypes}

  @tag :tmp_dir
  test "office and CAD files are recognised by name and content", %{tmp_dir: dir} do
    write = fn name, content ->
      path = Path.join(dir, name)
      File.write!(path, content)
      path
    end

    zip = <<"PK", 3, 4, "rest of a zip">>
    ole = <<0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, "rest">>

    assert {:ok, ".docx", _} = FileTypes.detect(write.("a.docx", zip), "Angebot.DOCX")
    assert {:ok, ".ods", _} = FileTypes.detect(write.("a.ods", zip), "Liste.ods")
    assert {:ok, ".xls", _} = FileTypes.detect(write.("a.xls", ole), "Liste.xls")
    assert {:ok, ".dwg", _} = FileTypes.detect(write.("a.dwg", "AC1032 drawing"), "Plan.dwg")

    assert {:ok, ".dxf", _} =
             FileTypes.detect(write.("a.dxf", "  0\nSECTION\n  2\nHEADER\n"), "Plan.dxf")

    # a renamed file of another type, and an unknown extension
    assert :error = FileTypes.detect(write.("b.docx", "<html><script>"), "Angebot.docx")
    assert :error = FileTypes.detect(write.("c.exe", zip), "setup.exe")
  end

  @tag :tmp_dir
  test "shared in a chat they are downloads; the media library refuses them", %{
    conn: conn,
    tmp_dir: dir
  } do
    path = Path.join(dir, "upload")
    File.write!(path, <<"PK", 3, 4, "spreadsheet">>)

    {:ok, asset} =
      Content.upload_chat_file(%{source_path: path, original_filename: "Holzliste.xlsx"},
        actor: user_fixture(roles: [:sales])
      )

    assert asset.kind == :document
    assert asset.file_name == "holzliste.xlsx"
    refute asset.library

    conn = get(conn, Asset.url(asset))
    assert response(conn, 200) == <<"PK", 3, 4, "spreadsheet">>
    assert get_resp_header(conn, "content-disposition") == ["attachment"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]

    assert {:error, _} =
             Content.upload_asset(
               %{source_path: path, original_filename: "Holzliste.xlsx", tags: ["x"]},
               actor: user_fixture(roles: [:contentmanager])
             )
  end
end
