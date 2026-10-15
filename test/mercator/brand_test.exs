defmodule Mercator.BrandTest do
  # changes application env, so not async
  use ExUnit.Case, async: false

  alias Mercator.Brand

  setup do
    previous =
      {Application.get_env(:mercator, :brand), Application.get_env(:mercator, :brand_key)}

    on_exit(fn ->
      restore(:brand, elem(previous, 0))
      restore(:brand_key, elem(previous, 1))
    end)
  end

  defp restore(key, nil), do: Application.delete_env(:mercator, key)
  defp restore(key, value), do: Application.put_env(:mercator, key, value)

  test "falls back to the neutral Mercator defaults" do
    Application.delete_env(:mercator, :brand)

    assert Brand.name() == "Mercator"
    assert Brand.get(:light_theme) == "light"
    assert Brand.image_path(:logo) == "/images/brands/mercator/logo.svg"
    assert Brand.tagline("de") == nil
  end

  test "configured values override the defaults" do
    Application.put_env(:mercator, :brand,
      name: "Biber Holz",
      assets: "/images/brands/biberholz",
      logo: "logo.webp",
      pin: "pin.webp",
      light_theme: "biberholz",
      tagline: %{"de" => "Holz seit 1928", "en" => "Timber since 1928"}
    )

    assert Brand.name() == "Biber Holz"
    assert Brand.get(:light_theme) == "biberholz"
    assert Brand.get(:dark_theme) == "dark"
    assert Brand.image_path(:pin) == "/images/brands/biberholz/pin.webp"
    assert Brand.tagline(:en) == "Timber since 1928"
    assert Brand.tagline("fr") == "Holz seit 1928"
  end

  test "a brand of config/brands/ is chosen by :brand_key (#43); :brand wins" do
    Application.delete_env(:mercator, :brand)
    Application.put_env(:mercator, :brand_key, :biberholz)

    assert Brand.name() == "Biber Holz"
    assert Brand.get(:order_prefix) == "BH"
    assert Brand.image_path(:logo) == "/images/brands/biberholz/logo.webp"

    for kind <- Brand.images(), path = Brand.image_path(kind) do
      assert File.regular?(Path.join("priv/static", path)), "missing #{path}"
    end

    Application.put_env(:mercator, :brand, name: "Biber Holz Test")
    assert Brand.name() == "Biber Holz Test"
    assert Brand.get(:order_prefix) == "BH"
  end

  test "the pin falls back to the logo" do
    Application.put_env(:mercator, :brand, logo: "logo.svg", pin: nil)

    assert Brand.image_path(:pin) == Brand.image_path(:logo)
  end

  test "every image of the shipped brands exists" do
    for brand <- ["mercator", "biberholz"],
        file <- File.ls!(Path.join(["priv/static/images/brands", brand])) do
      assert File.regular?(Path.join(["priv/static/images/brands", brand, file]))
    end

    Application.delete_env(:mercator, :brand)

    for kind <- Brand.images(), path = Brand.image_path(kind) do
      assert File.regular?(Path.join("priv/static", path)), "missing #{path}"
    end
  end
end
