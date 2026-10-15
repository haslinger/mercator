defmodule Mercator.OnlinePaymentFlowTest do
  # not async: the active payment provider is one setting row
  use Mercator.DataCase, async: false

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Operations.Incident
  alias Mercator.{Payments, Sales}
  alias Mercator.Payments.Simulator
  alias Mercator.Sales.{Baskets, Checkout, OnlinePayment}

  @moduletag :capture_log

  setup do
    {:ok, _setting} = Payments.activate(:simulator, user_fixture(roles: [:administrator]))
    gtc_fixture()
    customer = customer_fixture()
    [variant] = Ash.load!(product_fixture(), :variants).variants
    order = order_fixture(customer, variant, %{"payment_method" => "online"})
    %{customer: customer, variant: variant, order: order}
  end

  defp payment_id(order), do: Payments.latest(order).provider_id

  defp reload(order),
    do: Sales.get_order_by_number!(order.number, authorize?: false, load: :events)

  defp incidents, do: Ash.read!(Incident, authorize?: false)

  test "the order is placed for online payment", %{order: order} do
    assert order.payment_method == :online
    assert order.state == :placed
    assert Payments.payable?(order)
  end

  test "paid: the order is paid once, by the system", %{order: order} do
    assert {:ok, checkout_url} = Payments.start(order)
    assert checkout_url =~ "/payments/simulator/"
    assert %OnlinePayment{status: :open, provider: "simulator"} = Payments.latest(order)

    {:ok, _paid} = Simulator.complete(payment_id(order), :paid, "eps")
    assert {:ok, %{status: :paid, method: "eps"}} = Payments.notify(:simulator, payment_id(order))

    order = reload(order)
    assert order.state == :paid
    assert [%{to_state: :paid, user_id: nil, note: note}] = order.events
    assert note =~ "eps"
    refute Payments.payable?(order)

    # the same notification again changes nothing
    assert {:ok, %{status: :paid}} = Payments.notify(:simulator, payment_id(order))
    assert length(reload(order).events) == 1
  end

  test "failed: the order waits; a new attempt can be started", %{order: order} do
    {:ok, _url} = Payments.start(order)
    first = payment_id(order)
    {:ok, _failed} = Simulator.complete(first, :failed)
    Payments.notify(:simulator, first)

    order = reload(order)
    assert order.state == :placed
    assert Payments.payable?(order)

    {:ok, _url} = Payments.start(order)
    refute payment_id(order) == first
  end

  test "the return page check works without a webhook", %{order: order} do
    {:ok, _url} = Payments.start(order)
    {:ok, _paid} = Simulator.complete(payment_id(order), :paid)

    assert %{status: :paid} = Payments.sync_latest(order)
    assert reload(order).state == :paid
  end

  test "a wrong amount is an incident, the order stays unpaid", %{order: order} do
    {:ok, _url} = Payments.start(order)
    Ash.Seed.update!(Payments.latest(order), %{amount: Decimal.new("1")})
    {:ok, _paid} = Simulator.complete(payment_id(order), :paid)
    Payments.notify(:simulator, payment_id(order))

    assert reload(order).state == :placed
    assert [%{kind: :payment, order_id: order_id}] = incidents()
    assert order_id == order.id
  end

  test "payment for a cancelled order is an incident", %{order: order} do
    {:ok, _url} = Payments.start(order)

    Sales.cancel_order!(order, %{note: "Kunde storniert", notify: false},
      actor: user_fixture(roles: [:sales])
    )

    {:ok, _paid} = Simulator.complete(payment_id(order), :paid)
    Payments.notify(:simulator, payment_id(order))

    assert reload(order).state == :cancelled
    assert [%{kind: :payment, title: title}] = incidents()
    assert title =~ "stornierte"
  end

  test "notifications about unknown payments are incidents" do
    assert {:error, :unknown_payment} = Payments.notify(:simulator, "sim_unknown")
    assert [%{kind: :payment}] = incidents()
  end

  test "a provider that is down: error and incident, the order waits", %{order: order} do
    Application.put_env(:mercator, :payment_providers, [Simulator, Mercator.BrokenPaymentProvider])

    on_exit(fn -> Application.put_env(:mercator, :payment_providers, [Simulator]) end)
    {:ok, _setting} = Payments.activate(:broken, user_fixture(roles: [:administrator]))

    assert {:error, :provider} = Payments.start(order)
    assert [%{kind: :payment, order_id: order_id}] = incidents()
    assert order_id == order.id
    assert Payments.payable?(reload(order))
  end

  test "no online payment when the shipping costs are only estimated (#112)", ctx do
    freight = product_fixture(shipping: :freight)

    [variant] = Ash.load!(freight, :variants).variants
    Baskets.add({:user, ctx.customer}, variant.id, 1)

    checkout = Checkout.prepare(ctx.customer, %{"shipping_method" => "freight"})
    assert checkout.shipping_cost.estimate?
    refute :online in checkout.payment_methods

    checkout = Checkout.prepare(ctx.customer, %{"shipping_method" => "pickup"})
    assert :online in checkout.payment_methods
  end

  test "switched off: not payable, not offered", %{order: order, customer: customer} do
    {:ok, _setting} = Payments.activate(nil, user_fixture(roles: [:administrator]))

    refute Payments.payable?(order)
    refute :online in Checkout.prepare(customer, %{}).payment_methods
  end
end
