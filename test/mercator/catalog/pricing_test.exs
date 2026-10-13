defmodule Mercator.Catalog.PricingTest do
  use Mercator.DataCase, async: true

  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  defp variant_with_prices(prices, rate \\ 20) do
    tax_class = tax_class_fixture(rate: rate)
    product = product_fixture(tax_class_id: tax_class.id, variants: [%{prices: prices}])
    product |> Ash.load!(:variants) |> Map.fetch!(:variants) |> hd()
  end

  defp d(value), do: Decimal.new(value)

  test "net, VAT and gross for a quantity" do
    variant = variant_with_prices([%{amount: "12.3456"}])

    assert {:ok, info} = Catalog.price_for(variant, 3)
    assert Decimal.equal?(info.unit_net, d("12.3456"))
    assert Decimal.equal?(info.unit_gross, d("14.81"))
    assert Decimal.equal?(info.net, d("37.04"))
    assert Decimal.equal?(info.vat, d("7.41"))
    assert Decimal.equal?(info.gross, d("44.45"))
    refute info.promotion?
  end

  test "uses the product's tax class" do
    variant = variant_with_prices([%{amount: "100"}], 13)

    assert {:ok, info} = Catalog.price_for(variant, 1)
    assert Decimal.equal?(info.vat, d("13.00"))
    assert Decimal.equal?(info.gross, d("113.00"))
  end

  test "decimal quantities, e.g. 2.5 m³" do
    variant = variant_with_prices([%{amount: "520"}])

    assert {:ok, info} = Catalog.price_for(variant, "2.5")
    assert Decimal.equal?(info.net, d("1300.00"))
  end

  test "graduated prices: the highest reached tier applies" do
    variant =
      variant_with_prices([
        %{amount: "10", min_quantity: 1},
        %{amount: "9", min_quantity: 10},
        %{amount: "8", min_quantity: 50}
      ])

    assert {:ok, %{unit_net: one}} = Catalog.price_for(variant, 9)
    assert {:ok, %{unit_net: ten}} = Catalog.price_for(variant, 10)
    assert {:ok, %{unit_net: fifty}} = Catalog.price_for(variant, 120)

    assert Enum.map([one, ten, fifty], &Decimal.to_integer/1) == [10, 9, 8]
  end

  test "time-limited prices only apply in their period" do
    today = ~D[2026-10-13]

    variant =
      variant_with_prices([
        %{amount: "10"},
        %{amount: "12", valid_from: ~D[2027-01-01]},
        %{amount: "11", valid_until: ~D[2026-10-12]}
      ])

    assert {:ok, %{unit_net: price}} = Catalog.price_for(variant, 1, today)
    assert Decimal.equal?(price, 10)
  end

  test "a cheaper promotion wins and reports the regular price" do
    variant = variant_with_prices([%{amount: "10"}, %{amount: "8", promotion: true}])

    assert {:ok, info} = Catalog.price_for(variant, 1)
    assert info.promotion?
    assert Decimal.equal?(info.unit_net, 8)
    assert Decimal.equal?(info.regular_unit_net, 10)
    assert Decimal.equal?(info.regular_unit_gross, d("12.00"))
  end

  test "a promotion that is not cheaper is ignored" do
    variant = variant_with_prices([%{amount: "10"}, %{amount: "11", promotion: true}])

    assert {:ok, %{promotion?: false, unit_net: price}} = Catalog.price_for(variant, 1)
    assert Decimal.equal?(price, 10)
  end

  test "no applicable price" do
    variant = variant_with_prices([%{amount: "10", min_quantity: 5}])

    assert {:error, :no_price} = Catalog.price_for(variant, 1)
    assert {:error, :no_price} = Catalog.price_for(variant_with_prices([]), 1)
  end

  test "the from price is the lowest unit price over the active variants" do
    product =
      product_fixture(
        kind: :variants,
        variants: [
          %{prices: [%{amount: "30"}]},
          %{prices: [%{amount: "20"}]},
          %{prices: [%{amount: "5"}], active: false},
          %{prices: []}
        ]
      )

    assert {:ok, info} = Catalog.from_price(product)
    assert Decimal.equal?(info.unit_net, 20)
    assert {:error, :no_price} = Catalog.from_price(product_fixture(variants: [%{prices: []}]))
  end

  test "an invalid validity period is rejected" do
    variant = variant_with_prices([])

    assert {:error, %Ash.Error.Invalid{}} =
             Catalog.create_price(
               %{
                 variant_id: variant.id,
                 amount: "1",
                 valid_from: ~D[2026-12-01],
                 valid_until: ~D[2026-11-01]
               },
               authorize?: false
             )
  end
end
