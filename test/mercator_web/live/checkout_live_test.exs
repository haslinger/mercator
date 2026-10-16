defmodule MercatorWeb.CheckoutLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.{Accounts, Sales}
  alias Mercator.Sales.Baskets

  setup %{conn: conn} do
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

    Mercator.SalesFixtures.gtc_fixture()
    [variant] = Ash.load!(product_fixture(), :variants).variants

    %{conn: log_in_user(conn, user), user: user, variant: variant}
  end

  test "visitors are sent to sign in and come back to the checkout" do
    conn = get(build_conn(), ~p"/checkout/sign-in")

    assert redirected_to(conn) == ~p"/sign-in"
    assert get_session(conn, :return_to) == ~p"/checkout"
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/checkout")
  end

  test "an empty basket leads back to the basket", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/basket"}}} = live(conn, ~p"/checkout")
  end

  test "the basket links to the checkout", %{conn: conn, user: user, variant: variant} do
    Baskets.add({:user, user}, variant.id, 1)
    {:ok, view, _html} = live(conn, ~p"/basket")

    assert has_element?(view, ~s(#to-checkout[href="/checkout"]))
  end

  test "the address book links back to the checkout", %{conn: conn, user: user, variant: variant} do
    Baskets.add({:user, user}, variant.id, 1)
    {:ok, view, _html} = live(conn, ~p"/checkout")

    assert has_element?(
             view,
             ~s(#billing-step a[href="/account/addresses?return_to=%2Fcheckout"])
           )
  end

  test "places an order and shows the confirmation", %{conn: conn, user: user, variant: variant} do
    Baskets.add({:user, user}, variant.id, 1)
    {:ok, view, _html} = live(conn, ~p"/checkout")

    assert has_element?(view, ~s(#checkout-help a[href="/help"]))
    assert has_element?(view, "#shipping-parcel[checked]")
    assert has_element?(view, "#checkout-total", "129,90")

    view |> form("#checkout-form", checkout: %{shipping_method: "pickup"}) |> render_change()
    assert has_element?(view, "#checkout-total", "120,00")
    assert has_element?(view, "#payment-on_pickup")
    refute has_element?(view, "#delivery-step")

    # without accepting the terms
    view |> form("#checkout-form") |> render_submit()
    assert has_element?(view, "#problem-gtc")

    {:ok, _view, html} =
      view
      |> form("#checkout-form", checkout: %{gtc: "true", payment_method: "on_pickup"})
      |> render_submit()
      |> follow_redirect(conn)

    [order] = Sales.list_my_orders!(actor: user)
    assert order.payment_method == :on_pickup
    assert html =~ order.number
  end

  test "the order page is only for its customer", %{conn: conn, user: user, variant: variant} do
    Baskets.add({:user, user}, variant.id, 1)
    {:ok, order} = Sales.Checkout.place(user, %{"gtc" => "true"})

    {:ok, view, _html} = live(conn, ~p"/account/orders/#{order.number}")
    assert has_element?(view, "#order-number", order.number)
    assert has_element?(view, "#order-payment", "Vorauskasse")

    other = log_in_user(build_conn(), user_fixture())

    assert {:error, {:live_redirect, %{to: "/account/orders"}}} =
             live(other, ~p"/account/orders/#{order.number}")
  end
end
