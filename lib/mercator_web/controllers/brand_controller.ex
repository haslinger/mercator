defmodule MercatorWeb.BrandController do
  @moduledoc """
  Stable URLs for the current brand's images: `/brand/logo`, `/brand/pin`,
  `/brand/favicon` and `/brand/apple-touch-icon`.

  They redirect to the (digested) static file of the configured brand, so
  templates and compile-time configuration (e.g. the auth page banner) never
  need to know which brand is active.
  """
  use MercatorWeb, :controller

  alias Mercator.Brand

  @images Map.new(Brand.images(), &{&1 |> to_string() |> String.replace("_", "-"), &1})

  def show(conn, %{"image" => image}) do
    with {:ok, kind} <- Map.fetch(@images, image),
         path when is_binary(path) <- Brand.image_path(kind) do
      conn
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> redirect(to: static_path(conn, path))
    else
      _ -> send_resp(conn, :not_found, "Not Found")
    end
  end
end
