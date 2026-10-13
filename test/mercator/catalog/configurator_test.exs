defmodule Mercator.Catalog.ConfiguratorTest do
  use Mercator.DataCase, async: true

  import Mercator.CatalogFixtures

  alias Mercator.Catalog
  alias Mercator.Catalog.Configurator

  setup do
    %{product: configurable_product_fixture()}
  end

  defp d(value), do: Decimal.new(value)
  defp amounts(quote), do: Enum.map(quote.lines, &{&1.type, Decimal.to_string(&1.amount)})

  test "defaults: spruce, rough-sawn, 4000 × 100 × 120 mm", %{product: product} do
    assert Configurator.defaults(product) == %{
             "species" => "spruce",
             "surface" => "rough",
             "finish" => "none",
             "length" => "4000",
             "width" => "100",
             "thickness" => "120"
           }

    # 4 × 0.1 × 0.12 = 0.048 m³ < 0.05 minimum → 0.05 × 560 = 28.00, + 2.50 cutting fee
    assert {:ok, quote} = Catalog.quote(product, %{})
    assert Decimal.equal?(quote.measure, d("0.048"))
    assert Decimal.equal?(quote.billed_measure, d("0.05"))
    assert quote.measure_unit == :m3
    assert amounts(quote) == [base: "28.00", cutting_fee: "2.50"]
    assert Decimal.equal?(quote.net, d("30.50"))
    assert Decimal.equal?(quote.vat, d("6.10"))
    assert Decimal.equal?(quote.gross, d("36.60"))
  end

  test "base price from the species, percent and absolute surcharges", %{product: product} do
    selections = %{
      "species" => "oak",
      "surface" => "planed",
      "finish" => "oiled",
      "length" => "2000",
      "width" => "200",
      "thickness" => "50"
    }

    # 3 pieces × 2 × 0.2 × 0.05 = 0.06 m³ × 1650 = 99.00
    # planed +15 % = 14.85; oiled 3 × 8 = 24; cutting 3 × 2.50 = 7.50
    assert {:ok, quote} = Catalog.quote(product, selections, 3)

    assert amounts(quote) == [
             base: "99.00",
             surcharge: "14.85",
             surcharge: "24",
             cutting_fee: "7.50"
           ]

    assert Decimal.equal?(quote.net, d("145.35"))
    assert Decimal.equal?(quote.unit_net, d("48.45"))
  end

  test "dimensions are rounded up to whole centimetres", %{product: product} do
    assert {:ok, quote} = Catalog.quote(product, %{"length" => "1999", "width" => "101,5"})

    assert quote.selections["length"] == "2000"
    assert quote.selections["width"] == "110"
  end

  test "a line below the minimum order value is raised to it", %{product: product} do
    # 500 × 40 × 40 mm = 0.0008 m³ → billed 0.05 m³ = 28.00 + 2.50 = 30.50 ≥ 20, no minimum line
    assert {:ok, quote} =
             Catalog.quote(product, %{"length" => "500", "width" => "40", "thickness" => "40"})

    refute Enum.any?(quote.lines, &(&1.type == :minimum))

    expensive_minimum = configurable_product_fixture(min_order_value: "100")
    assert {:ok, quote} = Catalog.quote(expensive_minimum, %{})
    assert {:minimum, "69.50"} in amounts(quote)
    assert Decimal.equal?(quote.net, d("100.00"))
  end

  test "invalid values are reported per option", %{product: product} do
    assert {:error, errors} =
             Catalog.quote(product, %{
               "species" => "plastic",
               "length" => "9000",
               "width" => "abc"
             })

    assert Map.keys(errors) |> Enum.sort() == ["length", "species", "width"]
    assert {:error, %{"quantity" => _}} = Catalog.quote(product, %{}, 0)
    assert {:error, %{"quantity" => _}} = Catalog.quote(product, %{}, "1.5")
  end

  test "the configuration number is stable and differs per configuration", %{product: product} do
    {:ok, a} = Catalog.quote(product, %{"length" => "2000"})
    {:ok, b} = Catalog.quote(product, %{"length" => "2000"}, 5)
    {:ok, c} = Catalog.quote(product, %{"length" => "2010"})

    assert a.config_number == b.config_number
    assert a.config_number != c.config_number
    assert String.starts_with?(a.config_number, product.number <> "-")
  end

  test "configurable products need a pricing model" do
    assert_raise Ash.Error.Invalid, fn ->
      product_fixture(kind: :configurable, pricing: nil, state: :draft)
    end
  end

  test "options of invisible products are hidden" do
    draft = configurable_product_fixture(state: :draft)

    assert Ash.load!(draft, :options, authorize?: false).options != []

    assert Mercator.Catalog.ProductOption
           |> Ash.read!()
           |> Enum.all?(&(&1.product_id != draft.id))
  end
end
