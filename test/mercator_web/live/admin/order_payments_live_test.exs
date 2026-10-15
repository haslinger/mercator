defmodule MercatorWeb.Admin.OrderPaymentsLiveTest do
  # not async: the active payment provider is one setting row
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Payments
  alias Mercator.Payments.Simulator

  @moduletag :capture_log

  setup %{conn: conn} do
    {:ok, _setting} = Payments.activate(:simulator, user_fixture(roles: [:administrator]))
    gtc_fixture()
    [variant] = Ash.load!(product_fixture(), :variants).variants
    order = order_fixture(customer_fixture(), variant, %{"payment_method" => "online"})
    sales = user_fixture(roles: [:sales])

    %{conn: log_in_user(conn, sales), order: order, sales: sales}
  end

  defp pay(order, outcome, method \\ nil) do
    {:ok, _url} = Payments.start(order)
    payment = Payments.latest(order)
    {:ok, _done} = Simulator.complete(payment.provider_id, outcome, method)
    {:ok, payment} = Payments.notify(:simulator, payment.provider_id)
    payment
  end

  describe "payment attempts" do
    test "are listed with status, method and provider", %{conn: conn, order: order} do
      failed = pay(order, :failed)
      paid = pay(order, :paid, "eps")

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")

      assert has_element?(view, "#payment-#{failed.id}", "Fehlgeschlagen")
      assert has_element?(view, "#payment-#{paid.id}", "Bezahlt")
      assert has_element?(view, "#payment-#{paid.id}", "eps")
      assert has_element?(view, "#payment-#{paid.id}", paid.provider_id)
      assert has_element?(view, "#payment-#{paid.id}", Simulator.name())
    end

    test "link to the provider's dashboard when it has one", %{conn: conn, order: order} do
      payment = pay(order, :paid)

      Ash.update!(payment, %{dashboard_url: "https://my.mollie.com/dashboard/org_1/payments/x"},
        action: :set_status,
        authorize?: false
      )

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")

      assert has_element?(
               view,
               ~s(#payment-dashboard-#{payment.id}[href="https://my.mollie.com/dashboard/org_1/payments/x"])
             )
    end

    test "no section for orders without online payment", %{conn: conn, order: order} do
      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")
      refute has_element?(view, "#order-payments")
    end
  end
end
