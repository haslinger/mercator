defmodule MercatorWeb.UploadController do
  @moduledoc """
  Serves uploaded files from `Mercator.Uploads.root/0` under `/uploads/…`.
  File names contain the record id and never change, so they are cached
  for a year.
  """
  use MercatorWeb, :controller

  alias Mercator.Uploads

  @types %{
    ".webp" => "image/webp",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg"
  }

  def show(conn, %{"path" => segments}) do
    with {:ok, file} <- Uploads.resolve(segments),
         {:ok, type} <- Map.fetch(@types, file |> Path.extname() |> String.downcase()) do
      conn
      |> put_resp_content_type(type, nil)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_file(200, file)
    else
      _ -> send_resp(conn, :not_found, "Not Found")
    end
  end
end
