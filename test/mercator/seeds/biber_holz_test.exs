defmodule Mercator.Seeds.BiberHolzTest do
  use Mercator.DataCase, async: true

  alias Mercator.Catalog
  alias Mercator.Seeds

  setup do
    Seeds.run()
    :ok
  end

  defp product(number) do
    Catalog.get_product_by_number!(number, load: [:tax_class, :categories, variants: :prices])
  end

  test "creates 8 top categories with subcategories" do
    roots = Catalog.list_root_categories!()
    assert length(roots) == 8

    for root <- roots do
      assert Catalog.list_child_categories!(root.id) != []
    end

    assert length(Catalog.list_categories!()) == 8 + 32
  end

  test "creates 80 to 120 active products, each with a price, a category and translations" do
    products = Catalog.list_products!(load: [:categories, variants: :prices])

    assert length(products) in 80..120

    for product <- products do
      assert product.state == :active
      assert product.categories != [], "#{product.number} has no category"
      assert {:ok, _} = Catalog.from_price(product), "#{product.number} has no price"
      assert product.title["de"] && product.title["en"], "#{product.number} lacks a translation"
    end
  end

  test "uses the Austrian tax rates (#51)" do
    for number <- [
          "BH-SCHEIT-BUCHE",
          "BH-PELLETS-SACK",
          "BH-PELLETS-LOSE",
          "BH-CHRISTBAUM-NORDMANN"
        ] do
      assert Decimal.equal?(product(number).tax_class.rate, 13), number
    end

    for number <- ["BH-RUNDHOLZ-FI", "BH-KVH-FI", "BH-EINSTREU-SPAENE", "BH-BLOCK-TIROL"] do
      assert Decimal.equal?(product(number).tax_class.rate, 20), number
    end
  end

  test "covers the units from houses down to sawdust (#40)" do
    units =
      Catalog.list_products!(load: :variants)
      |> Enum.flat_map(& &1.variants)
      |> Enum.map(& &1.unit)
      |> Enum.uniq()
      |> Enum.sort()

    assert units == Enum.sort([:piece, :m2, :m3, :lfm, :fm, :rm, :srm, :kg, :t, :pallet, :sack])
  end

  test "variant products have several variants, timber prices follow the dimensions" do
    kvh = product("BH-KVH-FI")
    assert kvh.kind == :variants
    assert length(kvh.variants) == 6

    small = Enum.find(kvh.variants, &(&1.number == "BH-KVH-FI-60X120-5M"))
    # 0.06 m × 0.12 m × 5 m = 0.036 m³ at 520 €/m³
    assert {:ok, info} = Catalog.price_for(small, 1)
    assert Decimal.equal?(info.unit_net, Decimal.new("18.72"))
  end

  test "creates configurable products for all pricing models (#55)" do
    configurable = Enum.filter(Catalog.list_products!(), &(&1.kind == :configurable))

    assert Enum.map(configurable, & &1.pricing) |> Enum.sort() ==
             Enum.sort([:per_volume, :per_area, :per_area, :per_length])

    # default: spruce, rough-sawn, fresh, 4000 × 100 × 120 mm = 0.048 m³ → minimum 0.05 m³
    # 0.05 × 560 = 28.00 + 2.50 cutting fee = 30.50 net
    timber = Catalog.get_product_by_number!("BH-KVH-MASS")
    assert {:ok, quote} = Catalog.quote(timber, %{})
    assert Decimal.equal?(quote.net, Decimal.new("30.50"))

    # oak table top 2.0 × 1.0 m = 2 m² × 320 = 640, 40 mm +25 % = 160, live edge +90 → 890 net
    table = Catalog.get_product_by_number!("BH-TISCHPLATTE-MASS")

    assert {:ok, quote} =
             Catalog.quote(table, %{
               "length" => "2000",
               "width" => "1000",
               "thickness" => "40",
               "edge" => "live_edge"
             })

    assert Decimal.equal?(quote.net, Decimal.new("890.00"))
  end

  test "creates product relations" do
    larch = "BH-TD-LAE" |> product() |> Ash.load!(relations: :related_product)

    assert "BH-TD-SCHRAUBEN" in Enum.map(larch.relations, & &1.related_product.number)
  end

  test "is idempotent" do
    count = length(Catalog.list_products!())
    Seeds.run()

    assert length(Catalog.list_products!()) == count
    assert length(Catalog.list_categories!()) == 40
  end
end
