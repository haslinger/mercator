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

  @doc """
  A configurable product priced per m³ (timber cut to size):

    * species (base price): spruce 560 €/m³ (default), oak 1650 €/m³
    * surface (surcharge): rough-sawn (default), planed +15 %
    * finish (surcharge): none (default), oiled +8 € per piece
    * length 500–6000 mm (default 4000), width 40–300 (100), thickness 40–300 (120)
    * rounding 10 mm, cutting fee 2.50 € per piece, minimum 0.05 m³,
      minimum order value 20 €, 20 % VAT
  """
  def configurable_product_fixture(attrs \\ %{}) do
    product =
      product_fixture(
        Map.merge(
          %{
            kind: :configurable,
            pricing: :per_volume,
            rounding_mm: 10,
            cutting_fee: "2.50",
            min_billing_quantity: "0.05",
            min_order_value: "20",
            variants: [%{prices: []}]
          },
          Map.new(attrs)
        )
      )

    option = fn key, kind, role, extra ->
      Map.merge(
        %{product_id: product.id, key: key, name: %{"de" => key}, kind: kind, role: role},
        extra
      )
      |> Catalog.create_product_option!(authorize?: false)
    end

    choice = fn option, key, extra ->
      Map.merge(%{option_id: option.id, key: key, name: %{"de" => key}}, extra)
      |> Catalog.create_option_choice!(authorize?: false)
    end

    species = option.("species", :choice, :base_price, %{position: 1})
    choice.(species, "spruce", %{base_price: "560", default: true, position: 1})
    choice.(species, "oak", %{base_price: "1650", position: 2})

    surface = option.("surface", :choice, :surcharge, %{position: 2})
    choice.(surface, "rough", %{default: true, position: 1})
    choice.(surface, "planed", %{surcharge_percent: "15", position: 2})

    finish = option.("finish", :choice, :surcharge, %{position: 3})
    choice.(finish, "none", %{default: true, position: 1})
    choice.(finish, "oiled", %{surcharge_amount: "8", position: 2})

    option.("length", :number, :length, %{
      unit: "mm",
      min: "500",
      max: "6000",
      default: "4000",
      position: 4
    })

    option.("width", :number, :width, %{
      unit: "mm",
      min: "40",
      max: "300",
      default: "100",
      position: 5
    })

    option.("thickness", :number, :thickness, %{
      unit: "mm",
      min: "40",
      max: "300",
      default: "120",
      position: 6
    })

    product
  end
end
