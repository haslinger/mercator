defmodule MercatorWeb.Admin.ProductVariantsTabTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    product =
      product_fixture(
        number: "BH-DIELE",
        kind: :variants,
        variants: [
          %{number: "BH-DIELE-3M", name: %{"de" => "3 m"}, prices: [%{amount: "18.60"}]},
          %{number: "BH-DIELE-4M", name: %{"de" => "4 m"}, prices: [%{amount: "24.80"}]}
        ]
      )

    %{conn: log_in_user(conn, user_fixture(roles: [:productmanager])), product: product}
  end

  defp variants(product) do
    product.id
    |> Catalog.get_product!(authorize?: false, load: [variants: :prices])
    |> Map.fetch!(:variants)
  end

  defp open_tab(conn, product) do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=variants")
    view
  end

  test "lists variants with net and gross prices", %{conn: conn, product: product} do
    view = open_tab(conn, product)
    [v3, _v4] = variants(product)

    assert has_element?(view, "#variant-#{v3.id}", "BH-DIELE-3M")
    # 18.60 net + 20 % = 22.32 gross
    assert has_element?(view, "#prices-#{v3.id}", "22,32 €")
  end

  test "adds a variant with a suggested number", %{conn: conn, product: product} do
    view = open_tab(conn, product)

    view |> element("#new-variant") |> render_click()
    assert has_element?(view, "#variant-form input[value='BH-DIELE-3']")

    view
    |> form("#variant-form", form: %{name: %{de: "5 m"}, unit: "piece", stock: "120"})
    |> render_submit()

    assert [_, _, %{number: "BH-DIELE-3", stock: stock}] = variants(product)
    assert Decimal.equal?(stock, 120)
  end

  test "edits a variant and validates the number", %{conn: conn, product: product} do
    view = open_tab(conn, product)
    [v3, _] = variants(product)

    view |> element("#edit-variant-#{v3.id}") |> render_click()
    html = view |> form("#variant-form", form: %{number: "bad number"}) |> render_submit()
    assert html =~ "variant-form"

    view
    |> form("#variant-form", form: %{number: "BH-DIELE-3000", unit: "lfm"})
    |> render_submit()

    assert %{number: "BH-DIELE-3000", unit: :lfm} = hd(variants(product))
  end

  test "adds and deletes prices", %{conn: conn, product: product} do
    view = open_tab(conn, product)
    [v3, _] = variants(product)

    view |> element("#new-price-#{v3.id}") |> render_click()

    view
    |> form("#price-form", form: %{amount: "16.90", min_quantity: "50", promotion: "false"})
    |> render_submit()

    prices = hd(variants(product)).prices
    assert Enum.map(prices, &Decimal.to_string(&1.min_quantity)) |> Enum.sort() == ["1", "50"]

    tier = Enum.find(prices, &Decimal.equal?(&1.min_quantity, 50))
    view |> element("#delete-price-#{tier.id}") |> render_click()
    assert length(hd(variants(product)).prices) == 1
  end

  test "reorders variants by drag & drop", %{conn: conn, product: product} do
    view = open_tab(conn, product)
    [v3, v4] = variants(product)

    view |> element("#variant-list") |> render_hook("reorder", %{"id" => v4.id, "index" => 0})

    assert Enum.map(variants(product), & &1.id) == [v4.id, v3.id]
  end

  test "an active product keeps at least one variant", %{conn: conn} do
    single = product_fixture(variants: [%{prices: [%{amount: "5"}]}])
    view = open_tab(conn, single)
    [variant] = variants(single)

    view |> element("#delete-variant-#{variant.id}") |> render_click()

    assert [_] = variants(single)
    assert render(view) =~ "mindestens eine Variante"
  end
end
