defmodule MercatorWeb.UploadController do
  @moduledoc """
  Serves uploaded files from `Mercator.Uploads.root/0` under `/uploads/…`.
  File names contain the record id and never change, so they are cached
  for a year. Office and CAD files (`Mercator.Content.FileTypes`) are
  always downloaded, never shown in the browser.
  """
  use MercatorWeb, :controller

  alias Mercator.Content.FileTypes
  alias Mercator.Uploads

  @types %{
    ".webp" => "image/webp",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".pdf" => "application/pdf"
  }

  def show(conn, %{"path" => segments}) do
    with {:ok, file} <- Uploads.resolve(segments),
         {:ok, type, download?} <- type(Path.extname(file)) do
      conn
      |> put_resp_content_type(type, nil)
      |> put_resp_header("x-content-type-options", "nosniff")
      |> then(
        &if(download?, do: put_resp_header(&1, "content-disposition", "attachment"), else: &1)
      )
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_file(200, file)
    else
      _ -> send_resp(conn, :not_found, "Not Found")
    end
  end

  defp type(extension) do
    extension = String.downcase(extension)

    cond do
      type = @types[extension] -> {:ok, type, false}
      type = FileTypes.content_type(extension) -> {:ok, type, true}
      true -> :error
    end
  end
end
