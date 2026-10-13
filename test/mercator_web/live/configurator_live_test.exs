defmodule MercatorWeb.ConfiguratorLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.CatalogFixtures

  setup do
    %{
      product:
        configurable_product_fixture(
          title: %{"de" => "Bauholz nach Maß", "en" => "Timber cut to size"}
        )
    }
  end

  test "shows the configurator with the default configuration and its price", %{
    conn: conn,
    product: product
  } do
    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}")

    assert has_element?(view, "#configurator")
    assert has_element?(view, "#config-species option[selected][value=spruce]")
    assert has_element?(view, "#config-length[value='4000']")
    refute has_element?(view, "#variants")
    refute has_element?(view, "#quantity-form")

    # defaults: 30.50 net + 20 % = 36.60 gross (see ConfiguratorTest)
    assert view |> element("#quote-total") |> render() =~ "36,60 €"
    assert has_element?(view, "#config-number", product.number)
  end

  test "choices show their base price or surcharge (gross)", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}")

    # oak 1650 €/m³ net = 1980 € gross; oiled 8 € net = 9.60 € gross
    assert has_element?(view, "#config-species option[value=oak]", "1.980,00 €/m³")
    assert has_element?(view, "#config-surface option[value=planed]", "+15 %")
    assert has_element?(view, "#config-finish option[value=oiled]", "+9,60 €")
  end

  test "changing the configuration recalculates the price live", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}")

    view
    |> element("#configurator")
    |> render_change(%{
      "config" => %{
        "species" => "oak",
        "surface" => "planed",
        "finish" => "oiled",
        "length" => "2000",
        "width" => "200",
        "thickness" => "50"
      },
      "quantity" => "3"
    })

    # 145.35 net + 20 % = 174.42 gross (see ConfiguratorTest)
    assert view |> element("#quote-total") |> render() =~ "174,42 €"
    assert view |> element("#quote") |> render() =~ "Zuschnitt"
    # the breakdown is net, so it's labelled as such next to the gross dropdown prices
    assert view |> element("#quote thead") |> render() =~ "netto"
  end

  test "invalid dimensions show an error at the field", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}")

    html = view |> element("#configurator") |> render_change(%{"config" => %{"length" => "9000"}})

    assert has_element?(view, "#option-length .text-error")
    assert html =~ "höchstens 6000"
  end

  test "the category page shows the price of the default configuration", %{
    conn: conn,
    product: product
  } do
    category = category_fixture(slug: "nach-mass")
    Mercator.Catalog.categorize!(category.id, product.id, authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/kategorien/nach-mass")

    assert view |> element("#product-#{product.id} [data-role=price]") |> render() =~ "36,60 €"
  end
end
