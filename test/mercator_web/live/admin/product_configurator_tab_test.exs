defmodule MercatorWeb.Admin.ProductConfiguratorTabTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    %{
      conn: log_in_user(conn, user_fixture(roles: [:productmanager])),
      product: configurable_product_fixture()
    }
  end

  defp reload(product),
    do: Catalog.get_product!(product.id, authorize?: false, load: [options: :choices])

  defp option(product, key), do: Enum.find(reload(product).options, &(&1.key == key))

  test "the tab is only offered for configurable products", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}")
    assert has_element?(view, "#tab-configurator")

    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product_fixture().id}")
    refute has_element?(view, "#tab-configurator")
  end

  test "shows the options and the price of the default configuration", %{
    conn: conn,
    product: product
  } do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=configurator")

    assert has_element?(view, "#option-#{option(product, "species").id}")
    # defaults: 30.50 net + 20 % = 36.60 gross (see ConfiguratorTest)
    assert has_element?(view, "#preview-gross", "36,60 €")
  end

  test "changing the price settings updates the preview", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=configurator")

    view |> form("#settings-form", settings: %{cutting_fee: "0"}) |> render_submit()

    assert Decimal.equal?(reload(product).cutting_fee, 0)
    # 28.00 net + 20 % = 33.60 gross
    assert has_element?(view, "#preview-gross", "33,60 €")
  end

  test "adds a choice with a base price", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=configurator")
    species = option(product, "species")

    view |> element("#new-choice-#{species.id}") |> render_click()

    view
    |> form("#choice-form", form: %{key: "larch", name: %{de: "Lärche"}, base_price: "920"})
    |> render_submit()

    assert %{base_price: price} =
             Enum.find(option(product, "species").choices, &(&1.key == "larch"))

    assert Decimal.equal?(price, 920)
  end

  test "adds a number option and edits its range", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=configurator")

    view |> element("#new-option") |> render_click()

    view
    |> form("#option-form",
      form: %{
        key: "pieces_per_bundle",
        name: %{de: "Stück pro Bund"},
        kind: "number",
        role: "info",
        min: "1",
        max: "50",
        default: "10"
      }
    )
    |> render_submit()

    new = option(product, "pieces_per_bundle")
    assert new.kind == :number

    view |> element("#edit-option-#{new.id}") |> render_click()
    view |> form("#option-form", form: %{max: "100"}) |> render_submit()
    assert Decimal.equal?(option(product, "pieces_per_bundle").max, 100)
  end

  test "reorders and deletes options", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=configurator")
    finish = option(product, "finish")

    view |> element("#option-list") |> render_hook("reorder", %{"id" => finish.id, "index" => 0})
    assert hd(reload(product).options).key == "finish"

    view |> element("#delete-option-#{finish.id}") |> render_click()
    refute option(product, "finish")
  end
end
