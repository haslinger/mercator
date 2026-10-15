defmodule MercatorWeb.OnlinePaymentLiveTest do
  # not async: the active payment provider is one setting row
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.{Payments, Sales}
  alias Mercator.Payments.Simulator
  alias Mercator.Sales.Baskets

  setup %{conn: conn} do
    {:ok, _setting} = Payments.activate(:simulator, user_fixture(roles: [:administrator]))
    gtc_fixture()
    customer = customer_fixture()
    [variant] = Ash.load!(product_fixture(), :variants).variants
    %{conn: log_in_user(conn, customer), customer: customer, variant: variant}
  end

  defp path(url), do: URI.parse(url).path

  test "checkout → simulator → back: the order is paid", ctx do
    Baskets.add({:user, ctx.customer}, ctx.variant.id, 1)
    {:ok, view, _html} = live(ctx.conn, ~p"/checkout")
    assert has_element?(view, "#payment-online")

    assert {:error, {:redirect, %{to: url}}} =
             view
             |> form("#checkout-form", checkout: %{gtc: "true", payment_method: "online"})
             |> render_submit()

    assert path(url) =~ "/payments/simulator/"

    # the simulator's payment page
    {:ok, simulator, _html} = live(ctx.conn, path(url))
    assert has_element?(simulator, "#simulator-amount", "129,90")

    assert has_element?(simulator, "#test-cards", "4242 4242 4242 4242")

    # an unknown card: stays on the page
    simulator
    |> form("#card-form", card: %{number: "1234 5678", expiry: "12/39", cvc: "123"})
    |> render_submit()

    assert has_element?(simulator, "#card-error")

    assert {:error, {:redirect, %{to: return_url}}} =
             simulator
             |> form("#card-form",
               card: %{number: "4242 4242 4242 4242", expiry: "12/39", cvc: "123"}
             )
             |> render_submit()

    [order] = Sales.list_my_orders!(actor: ctx.customer)
    assert path(return_url) == "/account/orders/#{order.number}/payment"
    assert order.state == :paid

    # back in the shop: the status is checked, the page shows the order
    {:ok, view, _html} = live(ctx.conn, path(return_url))
    assert has_element?(view, "#order-state", "Bezahlt")
    refute has_element?(view, "#pay-now")
  end

  test "not paid: the order page offers to pay again", ctx do
    order = order_fixture(ctx.customer, ctx.variant, %{"payment_method" => "online"})
    {:ok, _url} = Payments.start(order)
    {:ok, _failed} = Simulator.complete(Payments.latest(order).provider_id, :canceled)

    {:ok, view, _html} = live(ctx.conn, ~p"/account/orders/#{order.number}/payment")
    assert has_element?(view, "#payment-not-completed")

    assert {:error, {:redirect, %{to: url}}} = view |> element("#pay-now") |> render_click()
    assert path(url) =~ "/payments/simulator/"
  end

  test "a declined card: back in the shop, not paid", ctx do
    order = order_fixture(ctx.customer, ctx.variant, %{"payment_method" => "online"})
    {:ok, url} = Payments.start(order)
    {:ok, simulator, _html} = live(ctx.conn, path(url))

    assert {:error, {:redirect, %{to: return_url}}} =
             simulator
             |> form("#card-form",
               card: %{number: "4000000000000002", expiry: "12/39", cvc: "123"}
             )
             |> render_submit()

    {:ok, view, _html} = live(ctx.conn, path(return_url))
    assert has_element?(view, "#payment-not-completed")
    assert has_element?(view, "#pay-now")
  end

  test "the webhook updates the order; unknown providers get 404", ctx do
    order = order_fixture(ctx.customer, ctx.variant, %{"payment_method" => "online"})
    {:ok, _url} = Payments.start(order)
    id = Payments.latest(order).provider_id
    {:ok, _paid} = Simulator.complete(id, :paid)

    assert build_conn() |> post(~p"/payments/simulator/webhook", %{id: id}) |> response(200)
    assert Sales.get_order_by_number!(order.number, authorize?: false).state == :paid

    assert build_conn() |> post("/payments/paypal/webhook", %{id: id}) |> response(404)
    assert build_conn() |> post(~p"/payments/simulator/webhook", %{}) |> response(400)
  end
end
