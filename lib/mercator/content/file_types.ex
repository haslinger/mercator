defmodule Mercator.Content.FileTypes do
  @moduledoc """
  Office and CAD files a consultant may share in a conversation, besides
  images and PDFs: Word, Excel and their LibreOffice counterparts, and
  AutoCAD drawings. A file is accepted when its extension is listed and
  its content matches the format (renamed files are rejected). They are
  served as downloads (`MercatorWeb.UploadController`).
  """

  # extension => {content type, how the content starts}
  @types %{
    ".doc" => {"application/msword", :ole},
    ".xls" => {"application/vnd.ms-excel", :ole},
    ".docx" => {"application/vnd.openxmlformats-officedocument.wordprocessingml.document", :zip},
    ".xlsx" => {"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", :zip},
    ".odt" => {"application/vnd.oasis.opendocument.text", :zip},
    ".ods" => {"application/vnd.oasis.opendocument.spreadsheet", :zip},
    ".dwg" => {"image/vnd.dwg", :dwg},
    ".dxf" => {"image/vnd.dxf", :dxf}
  }

  @doc "The accepted extensions, e.g. for a LiveView upload."
  def extensions, do: Map.keys(@types)

  @doc "The content type of an extension (with dot), or nil."
  def content_type(extension), do: with({type, _} <- @types[String.downcase(extension)], do: type)

  @doc """
  `{:ok, extension, content_type}` when the file at `path` named `name` is
  one of the types, else `:error`.
  """
  # sobelow_skip ["Traversal.FileModule"]
  def detect(path, name) do
    extension = name |> Path.extname() |> String.downcase()

    with {type, format} <- @types[extension],
         {:ok, head} <- File.open(path, [:read, :binary], &IO.binread(&1, 2048)),
         true <- is_binary(head) and matches?(format, head) do
      {:ok, extension, type}
    else
      _ -> :error
    end
  end

  defp matches?(:ole, <<0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, _::binary>>), do: true
  defp matches?(:zip, <<"PK", 3, 4, _::binary>>), do: true
  defp matches?(:dwg, <<"AC10", _::binary>>), do: true
  defp matches?(:dxf, head), do: String.valid?(head) and head =~ ~r/^\s*0\s*\r?\n\s*SECTION/
  defp matches?(_format, _head), do: false
end
