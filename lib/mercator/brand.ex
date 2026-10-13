defmodule Mercator.Brand do
  @moduledoc """
  Branding of a deployment: shop name, tagline, contact data, images and
  DaisyUI themes (decision #36). Each customer deployment configures its
  own brand; unset keys fall back to the neutral Mercator defaults.

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
    assets: "/images/brands/mercator",
    logo: "logo.svg",
    pin: nil,
    favicon: "favicon.svg",
    apple_touch_icon: "apple-touch-icon.png",
    light_theme: "light",
    dark_theme: "dark"
  ]

  @images [:logo, :pin, :favicon, :apple_touch_icon]

  @doc "The complete brand configuration as a keyword list."
  def config do
    Keyword.merge(@defaults, Application.get_env(:mercator, :brand, []))
  end

  @doc "A single brand setting."
  def get(key) when is_atom(key), do: Keyword.fetch!(config(), key)

  def name, do: get(:name)

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
