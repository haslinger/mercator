defmodule Mercator.CatalogFixtures do
  @moduledoc """
  Test helpers for catalogue data. Fixtures bypass policies.
  """

  alias Mercator.Catalog

  def category_fixture(attrs \\ %{}) do
    {state, attrs} = Map.pop(Map.new(attrs), :state, :active)
    name = Map.get(attrs, :name, %{"de" => "Kategorie #{System.unique_integer([:positive])}"})

    category =
      attrs
      |> Map.put(:name, name)
      |> Catalog.create_category!(authorize?: false)

    case state do
      :draft -> category
      :active -> Catalog.activate_category!(category, authorize?: false)
      :hidden -> Catalog.hide_category!(category, authorize?: false)
    end
  end

  def tax_class_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    key = Map.get(attrs, :key, "tax#{System.unique_integer([:positive])}")

    attrs
    |> Map.put_new(:name, %{"de" => "Normalsatz 20 %"})
    |> Map.put_new(:rate, 20)
    |> Map.put(:key, key)
    |> Catalog.create_tax_class!(authorize?: false)
  end

  @doc """
  A product with one variant and one price (net 100 per piece, 20 % VAT),
  active unless `state: :draft` is given. Options:

    * `:variants` – list of variant attribute maps (each may contain `:prices`)
    * any product attribute
  """
  def product_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {state, attrs} = Map.pop(attrs, :state, :active)
    {variants, attrs} = Map.pop(attrs, :variants, [%{prices: [%{amount: "100"}]}])
    n = System.unique_integer([:positive])

    product =
      attrs
      |> Map.put_new(:number, "P-#{n}")
      |> Map.put_new(:title, %{"de" => "Produkt #{n}", "en" => "Product #{n}"})
      |> Map.put_new_lazy(:tax_class_id, fn -> tax_class_fixture().id end)
      |> Catalog.create_product!(authorize?: false)

    for {variant_attrs, index} <- Enum.with_index(variants, 1) do
      variant_attrs
      |> Map.put_new(:number, "#{product.number}-#{index}")
      |> Map.put_new(:position, index)
      |> then(&variant_fixture(product, &1))
    end

    case state do
      :draft -> product
      :active -> Catalog.activate_product!(product, authorize?: false)
      :discontinued -> Catalog.discontinue_product!(product, authorize?: false)
    end
  end

  def variant_fixture(product, attrs \\ %{}) do
    {prices, attrs} = attrs |> Map.new() |> Map.pop(:prices, [])

    variant =
      attrs
      |> Map.put_new(:number, "#{product.number}-V#{System.unique_integer([:positive])}")
      |> Map.put(:product_id, product.id)
      |> Catalog.create_variant!(authorize?: false)

    for price <- prices do
      price
      |> Map.new()
      |> Map.put(:variant_id, variant.id)
      |> Catalog.create_price!(authorize?: false)
    end

    variant
  end
end
