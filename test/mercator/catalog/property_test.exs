defmodule Mercator.Catalog.PropertyTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup do
    group = Catalog.create_property_group!(%{name: %{"de" => "Holz"}}, authorize?: false)

    species =
      Catalog.create_property!(
        %{name: %{"de" => "Holzart"}, kind: :text, property_group_id: group.id},
        authorize?: false
      )

    thickness =
      Catalog.create_property!(
        %{name: %{"de" => "Stärke"}, kind: :number, unit: "mm", property_group_id: group.id},
        authorize?: false
      )

    impregnated =
      Catalog.create_property!(
        %{name: %{"de" => "imprägniert"}, kind: :boolean, property_group_id: group.id},
        authorize?: false
      )

    %{
      species: species,
      thickness: thickness,
      impregnated: impregnated,
      product: product_fixture()
    }
  end

  defp set(product, property, values) do
    values
    |> Map.merge(%{product_id: product.id, property_id: property.id})
    |> Catalog.set_product_property(authorize?: false)
  end

  test "values must match the property's kind", ctx do
    assert {:ok, _} =
             set(ctx.product, ctx.species, %{text_value: %{"de" => "Lärche", "en" => "Larch"}})

    assert {:ok, _} = set(ctx.product, ctx.thickness, %{number_value: "28"})
    assert {:ok, _} = set(ctx.product, ctx.impregnated, %{boolean_value: false})

    other = product_fixture()
    assert {:error, %Ash.Error.Invalid{}} = set(other, ctx.species, %{number_value: "28"})
    assert {:error, %Ash.Error.Invalid{}} = set(other, ctx.thickness, %{})

    assert {:error, %Ash.Error.Invalid{}} =
             set(other, ctx.thickness, %{number_value: "1", boolean_value: true})
  end

  test "a property is set once per product", ctx do
    assert {:ok, _} = set(ctx.product, ctx.thickness, %{number_value: "28"})
    assert {:error, %Ash.Error.Invalid{}} = set(ctx.product, ctx.thickness, %{number_value: "40"})
  end

  test "values of invisible products are hidden", ctx do
    draft = product_fixture(state: :draft)
    {:ok, _} = set(draft, ctx.thickness, %{number_value: "28"})
    {:ok, _} = set(ctx.product, ctx.thickness, %{number_value: "40"})

    assert [%{number_value: value}] = Ash.read!(Mercator.Catalog.ProductProperty)
    assert Decimal.equal?(value, 40)
  end

  test "only product managers and administrators define properties" do
    group_attrs = %{name: %{"de" => "Oberfläche"}}

    assert {:error, %Ash.Error.Forbidden{}} =
             Catalog.create_property_group(group_attrs, actor: user_fixture(roles: [:sales]))

    assert {:ok, _} =
             Catalog.create_property_group(group_attrs,
               actor: user_fixture(roles: [:productmanager])
             )
  end
end
