defmodule MercatorWeb.Admin.ProductPropertiesTabTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
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

    %{
      conn: log_in_user(conn, user_fixture(roles: [:productmanager])),
      product: product_fixture(),
      group: group,
      species: species,
      thickness: thickness
    }
  end

  defp values(product) do
    Catalog.get_product!(product.id, authorize?: false, load: [product_properties: :property]).product_properties
  end

  test "adds a value for an existing property", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.product.id}?tab=properties")
    assert has_element?(view, "#no-properties")

    view |> element("#add-property") |> render_click()

    view
    |> form("#add-property-form", %{"property_id" => ctx.thickness.id, "number_value" => "28"})
    |> render_submit()

    assert [%{property_id: id, number_value: value}] = values(ctx.product)
    assert id == ctx.thickness.id
    assert Decimal.equal?(value, 28)
    assert has_element?(view, "#properties-table", "28 mm")
  end

  test "creates a new property with its value", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.product.id}?tab=properties")
    view |> element("#add-property") |> render_click()

    view
    |> form("#add-property-form", %{
      "property_id" => "",
      "new_property" => %{
        "name" => %{"de" => "Imprägniert", "en" => "Impregnated"},
        "kind" => "boolean",
        "property_group_id" => ctx.group.id
      },
      "boolean_value" => "true"
    })
    |> render_submit()

    assert [%{boolean_value: true, property: %{name: %{"de" => "Imprägniert"}}}] =
             values(ctx.product)
  end

  test "rejects a value of the wrong kind", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.product.id}?tab=properties")
    view |> element("#add-property") |> render_click()

    html =
      view
      |> form("#add-property-form", %{
        "property_id" => ctx.thickness.id,
        "text_value" => %{"de" => "dick"}
      })
      |> render_submit()

    assert values(ctx.product) == []
    assert html =~ "alert-error"
  end

  test "edits and deletes values", ctx do
    {:ok, value} =
      Catalog.set_product_property(
        %{
          product_id: ctx.product.id,
          property_id: ctx.species.id,
          text_value: %{"de" => "Fichte"}
        },
        authorize?: false
      )

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.product.id}?tab=properties")

    view |> element("#edit-property-#{value.id}") |> render_click()

    view
    |> form("#edit-property-form", %{"text_value" => %{"de" => "Lärche", "en" => "Larch"}})
    |> render_submit()

    assert [%{text_value: %{"de" => "Lärche", "en" => "Larch"}}] = values(ctx.product)

    view |> element("#delete-property-#{value.id}") |> render_click()
    assert values(ctx.product) == []
  end
end
