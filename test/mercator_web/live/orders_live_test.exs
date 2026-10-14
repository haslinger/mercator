defmodule MercatorWeb.OrdersLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.{Accounts, Sales}
  alias Mercator.Sales.Baskets

  setup %{conn: conn} do
    user = customer_fixture()
    Ash.Seed.seed!(Sales.Gtc, %{version: ~D[2026-10-01], text: %{"de" => "AGB"}})
    [variant] = Ash.load!(product_fixture(), :variants).variants

    %{conn: log_in_user(conn, user), user: user, variant: variant}
  end

  defp customer_fixture do
    user = user_fixture()

    Accounts.create_address!(
      %{
        name: "Karl Luchs",
        street: "Waldweg 3",
        postcode: "6020",
        city: "Innsbruck",
        country: "AT"
      },
      actor: user
    )

    user
  end

  defp place_order(user, variant, quantity) do
    Baskets.add({:user, user}, variant.id, quantity)
    {:ok, order} = Sales.Checkout.place(user, %{"gtc" => "true"})
    order
  end

  test "visitors are sent to sign in" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/account/orders")
  end

  test "shows a hint without orders", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/account/orders")

    assert has_element?(view, "#no-orders")
  end

  test "lists only the customer's own orders, each linking to its page",
       %{conn: conn, user: user, variant: variant} do
    first = place_order(user, variant, 1)
    second = place_order(user, variant, 2)
    foreign = place_order(customer_fixture(), variant, 1)

    {:ok, view, _html} = live(conn, ~p"/account/orders")

    refute has_element?(view, "#no-orders")
    assert has_element?(view, "#orders-#{first.id} a[href='/account/orders/#{first.number}']")
    assert has_element?(view, "#orders-#{second.id}", second.number)
    refute has_element?(view, "#orders-#{foreign.id}")

    {:ok, order_view, _html} =
      view |> element("#orders-#{first.id} a") |> render_click() |> follow_redirect(conn)

    assert has_element?(order_view, "#order-number", first.number)
  end

  test "the account page and the order page link to the list",
       %{conn: conn, user: user, variant: variant} do
    {:ok, view, _html} = live(conn, ~p"/account")
    assert has_element?(view, ~s(#orders-link[href="/account/orders"]))
    assert has_element?(view, ~s(#my-orders-link[href="/account/orders"]))

    order = place_order(user, variant, 1)
    {:ok, view, _html} = live(conn, ~p"/account/orders/#{order.number}")
    assert has_element?(view, ~s(#back-to-orders[href="/account/orders"]))
  end
end
