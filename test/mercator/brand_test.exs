defmodule Mercator.BrandTest do
  # changes application env, so not async
  use ExUnit.Case, async: false

  alias Mercator.Brand

  setup do
    previous = Application.get_env(:mercator, :brand)
    on_exit(fn -> restore(previous) end)
  end

  defp restore(nil), do: Application.delete_env(:mercator, :brand)
  defp restore(value), do: Application.put_env(:mercator, :brand, value)

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
