defmodule MercatorWeb.ManifestController do
  @moduledoc """
  The web app manifest (`/manifest.webmanifest`) of the configured brand, so
  the shop can be installed as an app (PWA), e.g. by sales staff.
  """
  use MercatorWeb, :controller

  alias Mercator.Brand

  def show(conn, _params) do
    manifest = %{
      name: Brand.name(),
      short_name: Brand.short_name(),
      description: Brand.tagline(conn.assigns[:locale] || "de"),
      lang: conn.assigns[:locale] || "de",
      start_url: "/",
      scope: "/",
      display: "standalone",
      theme_color: Brand.get(:theme_color),
      background_color: Brand.get(:background_color),
      icons: [
        icon(conn, :icon_192, "192x192", "any"),
        icon(conn, :icon_512, "512x512", "any"),
        icon(conn, :icon_maskable, "512x512", "maskable")
      ]
    }

    conn
    |> put_resp_content_type("application/manifest+json")
    |> send_resp(200, Jason.encode!(manifest))
  end

  defp icon(conn, kind, sizes, purpose) do
    %{
      src: static_path(conn, Brand.image_path(kind)),
      sizes: sizes,
      type: "image/png",
      purpose: purpose
    }
  end
end
