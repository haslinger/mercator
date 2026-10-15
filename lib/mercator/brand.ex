defmodule Mercator.Brand do
  @moduledoc """
  Branding of a deployment: shop name, tagline, contact data, images and
  DaisyUI themes (decision #36). Unset keys fall back to the neutral
  Mercator defaults.

  Brands that come with Mercator live in `config/brands/` (`:brands`, e.g.
  Biber Holz) and are chosen by `:brand_key` (`BRAND=biberholz` in
  production, #43). A deployment can also configure its own brand, which
  wins over the chosen one:

      config :mercator, :brand,
        name: "Biber Holz",
        tagline: %{"de" => "…", "en" => "…"},
        assets: "/images/brands/biberholz",
        logo: "logo.webp",
        light_theme: "biberholz",
        dark_theme: "biberholz-dark"

  Image files live in `priv/static/<assets>/`. The web layer serves them under
  stable URLs (`/brand/logo`, `/brand/pin`, …), see `MercatorWeb.BrandController`.
  """

  @defaults [
    name: "Mercator",
    tagline: %{},
    email: nil,
    phone: nil,
    address: nil,
    bank: nil,
    order_prefix: nil,
    assets: "/images/brands/mercator",
    logo: "logo.svg",
    pin: nil,
    favicon: "favicon.svg",
    apple_touch_icon: "apple-touch-icon.png",
    icon_192: "icon-192.png",
    icon_512: "icon-512.png",
    icon_maskable: "icon-maskable-512.png",
    short_name: nil,
    theme_color: "#4b5563",
    background_color: "#ffffff",
    light_theme: "light",
    dark_theme: "dark"
  ]

  @images [:logo, :pin, :favicon, :apple_touch_icon, :icon_192, :icon_512, :icon_maskable]

  @doc "The complete brand configuration as a keyword list."
  def config do
    @defaults
    |> Keyword.merge(chosen())
    |> Keyword.merge(Application.get_env(:mercator, :brand, []))
  end

  defp chosen do
    case Application.get_env(:mercator, :brand_key) do
      nil -> []
      key -> :mercator |> Application.get_env(:brands, []) |> Keyword.get(key, [])
    end
  end

  @doc "A single brand setting."
  def get(key) when is_atom(key), do: Keyword.fetch!(config(), key)

  def name, do: get(:name)

  @doc "Short name for the installed app (PWA), falling back to the name."
  def short_name, do: get(:short_name) || name()

  @doc """
  The tagline in the given locale, falling back to German, then nil.
  Line breaks (`\\n`) are kept; templates render them with `whitespace-pre-line`.
  """
  def tagline(locale) do
    tagline = get(:tagline)
    Map.get(tagline, to_string(locale)) || Map.get(tagline, "de")
  end

  @doc "The image kinds a brand can provide."
  def images, do: @images

  @doc """
  The static path of a brand image (e.g. `"/images/brands/biberholz/pin.webp"`),
  or nil if the brand has none. Falls back to the logo for the pin.
  """
  def image_path(kind) when kind in @images do
    case {get(kind), kind} do
      {nil, :pin} -> image_path(:logo)
      {nil, _kind} -> nil
      {file, _kind} -> Path.join(get(:assets), file)
    end
  end
end
