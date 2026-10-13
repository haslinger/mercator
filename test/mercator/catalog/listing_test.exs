defmodule Mercator.Catalog.ListingTest do
  use Mercator.DataCase, async: true

  import Mercator.CatalogFixtures

  alias Mercator.Catalog
  alias Mercator.Catalog.Listing

  setup do
    group = Catalog.create_property_group!(%{name: %{"de" => "Holz"}}, authorize?: false)

    species =
      Catalog.create_property!(
        %{name: %{"de" => "Holzart"}, kind: :text, property_group_id: group.id},
        authorize?: false
      )

    make = fn title, price, wood, extra ->
      product =
        product_fixture(
          Map.merge(%{title: %{"de" => title}, variants: [%{prices: [%{amount: price}]}]}, extra)
        )

      Catalog.set_product_property!(
        %{
          product_id: product.id,
          property_id: species.id,
          text_value: %{"de" => wood, "en" => wood <> " (en)"}
        },
        authorize?: false
      )

      product
    end

    products = [
      make.("Brett Lärche", "10", "Lärche", %{new_arrival: true}),
      make.("Balken Fichte", "50", "Fichte", %{}),
      make.("Diele Lärche", "30", "Lärche", %{bestseller: true})
    ]

    products = Ash.load!(products, Listing.loads(), authorize?: false)
    %{products: products, species: species}
  end

  defp titles(listing), do: Enum.map(listing.entries, fn {p, _} -> p.title["de"] end)

  test "without filters all products in their order, with facets", %{
    products: products,
    species: species
  } do
    listing = Listing.build(products, %{}, "de")

    assert listing.count == 3 and listing.total == 3
    assert [%{property: %{id: id}, values: values}] = listing.facets
    assert id == species.id
    assert values == [{"Fichte", "Fichte", 1}, {"Lärche", "Lärche", 2}]
  end

  test "facet labels follow the locale, keys stay German", %{products: products} do
    [%{values: values}] = Listing.build(products, %{}, "en").facets

    assert {"Lärche", "Lärche (en)", 2} in values
  end

  test "filters by property value", %{products: products, species: species} do
    listing = Listing.build(products, %{"p" => %{species.id => ["Lärche"]}}, "de")

    assert Enum.sort(titles(listing)) == ["Brett Lärche", "Diele Lärche"]
  end

  test "filters by gross price range", %{products: products} do
    # gross prices: 12, 60, 36
    listing = Listing.build(products, %{"min" => "20", "max" => "40"}, "de")

    assert titles(listing) == ["Diele Lärche"]
  end

  test "filters by flags", %{products: products} do
    assert titles(Listing.build(products, %{"new" => "1"}, "de")) == ["Brett Lärche"]
    assert titles(Listing.build(products, %{"bestseller" => "1"}, "de")) == ["Diele Lärche"]
    assert titles(Listing.build(products, %{"sale" => "1"}, "de")) == []
  end

  test "sorts by price and name", %{products: products} do
    assert titles(Listing.build(products, %{"sort" => "price_asc"}, "de")) ==
             ["Brett Lärche", "Diele Lärche", "Balken Fichte"]

    assert titles(Listing.build(products, %{"sort" => "price_desc"}, "de")) ==
             ["Balken Fichte", "Diele Lärche", "Brett Lärche"]

    assert titles(Listing.build(products, %{"sort" => "name"}, "de")) ==
             ["Balken Fichte", "Brett Lärche", "Diele Lärche"]
  end
end
