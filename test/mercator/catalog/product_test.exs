defmodule Mercator.Catalog.ProductTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  describe "products" do
    test "are created as drafts with a slug from the German title" do
      product =
        product_fixture(
          state: :draft,
          number: "BH-KVH-001",
          title: %{"de" => "Konstruktionsvollholz Fichte", "en" => "Structural timber spruce"},
          highlights: [%{"de" => "technisch getrocknet"}, %{"de" => "keilgezinkt"}]
        )

      assert product.state == :draft
      assert product.kind == :simple
      assert product.slug == "konstruktionsvollholz-fichte"
      assert Enum.map(product.highlights, & &1["de"]) == ["technisch getrocknet", "keilgezinkt"]
    end

    test "article numbers are upper case and unique" do
      product_fixture(number: "BH-001")

      assert_raise Ash.Error.Invalid, fn -> product_fixture(number: "BH-001") end
      assert_raise Ash.Error.Invalid, fn -> product_fixture(number: "bh-002") end
    end

    test "a product needs a variant to be activated" do
      product = product_fixture(state: :draft, variants: [])

      assert {:error, %Ash.Error.Invalid{}} = Catalog.activate_product(product, authorize?: false)

      variant_fixture(product)
      assert {:ok, %{state: :active}} = Catalog.activate_product(product, authorize?: false)
    end

    test "discontinued products can be activated again" do
      product = product_fixture(state: :discontinued)

      assert {:ok, %{state: :active}} = Catalog.activate_product(product, authorize?: false)
    end

    test "products are assigned to categories" do
      category = category_fixture()
      product = product_fixture()

      Catalog.categorize!(category.id, product.id, authorize?: false)

      assert [%{id: id}] = Ash.load!(category, :products).products
      assert id == product.id

      assert_raise Ash.Error.Invalid, fn ->
        Catalog.categorize!(category.id, product.id, authorize?: false)
      end
    end
  end

  describe "visibility" do
    test "customers see only active products and their active variants" do
      active = product_fixture(variants: [%{prices: [%{amount: "10"}]}, %{active: false}])
      draft = product_fixture(state: :draft)
      discontinued = product_fixture(state: :discontinued)

      assert {:ok, _} = Catalog.get_product(active.id)
      assert {:error, _} = Catalog.get_product(draft.id)
      assert {:error, _} = Catalog.get_product(discontinued.id)

      variants = Ash.load!(active, :variants).variants
      assert length(variants) == 1
      assert [%{prices: [_price]}] = Ash.load!(variants, :prices)
    end

    test "product managers see drafts" do
      draft = product_fixture(state: :draft)

      assert {:ok, _} =
               Catalog.get_product(draft.id, actor: user_fixture(roles: [:productmanager]))
    end

    test "categorizations of invisible products are hidden" do
      category = category_fixture()
      Catalog.categorize!(category.id, product_fixture(state: :draft).id, authorize?: false)

      assert Ash.load!(category, :products).products == []
    end
  end

  describe "permissions" do
    test "only product managers and administrators change products" do
      tax_class = tax_class_fixture()
      attrs = %{number: "NEW-1", title: %{"de" => "Neu"}, tax_class_id: tax_class.id}

      for actor <- [nil, user_fixture(), user_fixture(roles: [:sales, :contentmanager])] do
        assert {:error, %Ash.Error.Forbidden{}} = Catalog.create_product(attrs, actor: actor)
      end

      assert {:ok, _} =
               Catalog.create_product(attrs, actor: user_fixture(roles: [:productmanager]))
    end
  end
end
