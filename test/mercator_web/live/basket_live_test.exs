defmodule MercatorWeb.BasketLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.CatalogFixtures

  setup do
    product =
      product_fixture(
        title: %{"de" => "Terrassendiele"},
        kind: :variants,
        variants: [
          %{number: "DIELE-4M", name: %{"de" => "4 m"}, prices: [%{amount: "24.80"}]},
          %{number: "DIELE-5M", name: %{"de" => "5 m"}, prices: [%{amount: "31.00"}]}
        ]
      )

    %{product: product}
  end

  # one browser session: the first request sets the basket token cookie
  defp session(conn), do: conn |> get(~p"/") |> recycle()

  test "an empty basket", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/warenkorb")

    assert has_element?(view, "#empty-basket")
  end

  test "adding on the product page updates the badge and the basket", %{
    conn: conn,
    product: product
  } do
    conn = session(conn)
    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}?variant=DIELE-5M")
    view |> element("#quantity-form") |> render_change(%{"quantity" => "3"})
    view |> element("#add-to-basket") |> render_click()

    assert has_element?(view, "#basket-count", "1")

    {:ok, basket, _html} = live(conn, ~p"/warenkorb")
    # 3 × 31.00 net = 93.00 net, 111.60 gross
    assert has_element?(basket, "#total-net", "93,00 €")
    assert has_element?(basket, "#total-gross", "111,60 €")
  end

  test "configurations are added and described", %{conn: conn} do
    conn = session(conn)
    product = configurable_product_fixture()

    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}")

    view
    |> element("#configurator")
    |> render_change(%{"config" => %{"species" => "oak"}, "quantity" => "2"})

    view |> element("#add-to-basket") |> render_click()

    {:ok, basket, _html} = live(conn, ~p"/warenkorb")
    assert render(basket) =~ product.number <> "-"
    assert render(basket) =~ "species: oak"
  end

  test "changes quantities and removes items", %{conn: conn, product: product} do
    conn = session(conn)
    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}")
    view |> element("#add-to-basket") |> render_click()

    {:ok, basket, _html} = live(conn, ~p"/warenkorb")

    [item_id] =
      basket
      |> render()
      |> then(&Regex.scan(~r/id="item-([0-9a-f-]+)"/, &1))
      |> Enum.map(&List.last/1)

    basket
    |> element("#quantity-form-#{item_id}")
    |> render_change(%{"item" => item_id, "quantity" => "10"})

    # 10 × 24.80 = 248 net, 297.60 gross
    assert has_element?(basket, "#total-gross", "297,60 €")

    basket
    |> element("#quantity-form-#{item_id}")
    |> render_change(%{"item" => item_id, "quantity" => "1,5"})

    assert render(basket) =~ "ganze Zahl"

    basket |> element("#remove-#{item_id}") |> render_click()
    assert has_element?(basket, "#empty-basket")
  end

  test "each browser session has its own basket", %{conn: conn, product: product} do
    conn = session(conn)
    {:ok, view, _html} = live(conn, ~p"/produkte/#{product.slug}")
    view |> element("#add-to-basket") |> render_click()

    {:ok, other, _html} = live(build_conn(), ~p"/warenkorb")
    assert has_element?(other, "#empty-basket")
  end
end
