defmodule Mercator.Catalog.SlugTest do
  use ExUnit.Case, async: true

  doctest Mercator.Catalog.Slug

  alias Mercator.Catalog.Slug

  test "transliterates umlauts and sharp s" do
    assert Slug.slugify("Größe & Maß") == "groesse-mass"
    assert Slug.slugify("Brennholz & Energie") == "brennholz-energie"
  end

  test "removes accents and collapses separators" do
    assert Slug.slugify("  Pellets -- lose  (Tonne) ") == "pellets-lose-tonne"
    assert Slug.slugify("Mélèze") == "meleze"
  end
end
