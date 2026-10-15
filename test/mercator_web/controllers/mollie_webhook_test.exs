defmodule MercatorWeb.MollieWebhookTest do
  # not async: registers Mollie and switches the active provider (global)
  use MercatorWeb.ConnCase, async: false

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Operations.Incident
  alias Mercator.{Payments, Sales}
  alias Mercator.Payments.{Mollie, Simulator}

  @moduletag :capture_log

  setup do
    previous = Application.get_env(:mercator, :payment_providers)
    Application.put_env(:mercator, :payment_providers, [Simulator, Mollie])
    on_exit(fn -> Application.put_env(:mercator, :payment_providers, previous) end)

    {:ok, _setting} = Payments.activate(:mollie, user_fixture(roles: [:administrator]))
    gtc_fixture()
    [variant] = Ash.load!(product_fixture(), :variants).variants
    order = order_fixture(customer_fixture(), variant, %{"payment_method" => "online"})
    %{order: order}
  end

  # Mollie's API as seen by the shop: the payment `tr_flow` with `status`
  defp mollie(order, status) do
    Req.Test.stub(Mollie, fn conn ->
      conn
      |> Plug.Conn.put_status(if conn.method == "POST", do: 201, else: 200)
      |> Req.Test.json(%{
        "id" => "tr_flow",
        "status" => status,
        "method" => "creditcard",
        "amount" => %{
          "currency" => "EUR",
          "value" => Decimal.to_string(Decimal.round(order.gross, 2))
        },
        "_links" => %{
          "checkout" => %{"href" => "https://www.mollie.com/checkout/test-mode?tr_flow"}
        }
      })
    end)
  end

  test "checkout, then Mollie's webhook marks the order paid", %{conn: conn, order: order} do
    mollie(order, "open")
    assert {:ok, "https://www.mollie.com/checkout/" <> _} = Payments.start(order)

    mollie(order, "paid")
    conn = post(conn, ~p"/payments/mollie/webhook", %{"id" => "tr_flow"})
    assert response(conn, 200)

    order = Sales.get_order_by_number!(order.number, authorize?: false)
    assert order.state == :paid
    assert %{provider: "mollie", status: :paid, method: "creditcard"} = Payments.latest(order)
  end

  test "refunded: a later webhook that still says paid changes nothing", ctx do
    %{conn: conn, order: order} = ctx
    mollie(order, "open")
    {:ok, _url} = Payments.start(order)
    mollie(order, "paid")
    post(conn, ~p"/payments/mollie/webhook", %{"id" => "tr_flow"})

    sales = user_fixture(roles: [:sales])
    order = Sales.get_order_by_number!(order.number, authorize?: false)
    Sales.cancel_order!(order, %{note: "Kunde storniert", notify: false}, actor: sales)

    # Mollie accepts the refund but reports the payment "paid" until it is processed
    mollie(order, "paid")
    assert {:ok, %{status: :refunded}} = Payments.refund(Payments.latest(order), sales)

    conn = post(build_conn(), ~p"/payments/mollie/webhook", %{"id" => "tr_flow"})
    assert response(conn, 200)
    assert %{status: :refunded} = Payments.latest(order)
    assert Ash.read!(Incident, authorize?: false) == []
  end

  test "a refund Mollie refuses is an incident", %{conn: conn, order: order} do
    mollie(order, "open")
    {:ok, _url} = Payments.start(order)
    mollie(order, "paid")
    post(conn, ~p"/payments/mollie/webhook", %{"id" => "tr_flow"})

    Req.Test.stub(Mollie, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{"status" => 422, "detail" => "The payment is already refunded"})
    end)

    assert {:error, :provider} =
             Payments.refund(Payments.latest(order), user_fixture(roles: [:sales]))

    assert %{status: :paid} = Payments.latest(order)
    assert [%{kind: :payment, order_id: order_id}] = Ash.read!(Incident, authorize?: false)
    assert order_id == order.id
  end

  test "a webhook for an unknown payment is accepted and changes nothing", %{conn: conn} do
    conn = post(conn, ~p"/payments/mollie/webhook", %{"id" => "tr_unknown"})
    assert response(conn, 200)
  end
end
