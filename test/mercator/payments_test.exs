defmodule Mercator.PaymentsTest do
  # not async: the active provider is one setting row shared by all tests
  use Mercator.DataCase, async: false

  import Mercator.AccountsFixtures

  alias Mercator.Payments
  alias Mercator.Payments.Simulator
  alias Mercator.Sales.Payment

  setup do
    %{admin: user_fixture(roles: [:administrator])}
  end

  describe "switching providers" do
    test "no online payment until an administrator activates a provider", %{admin: admin} do
      refute Payments.online?()
      refute :online in Payment.methods_for(user_fixture(), :parcel)

      assert {:ok, _setting} = Payments.activate(:simulator, admin)
      assert Payments.active() == Simulator
      assert :online in Payment.methods_for(user_fixture(), :parcel)

      assert {:ok, _setting} = Payments.activate(nil, admin)
      refute Payments.online?()
    end

    test "only registered providers, only by administrators", %{admin: admin} do
      assert {:error, :unknown_provider} = Payments.activate(:paypal, admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Payments.activate(:simulator, user_fixture(roles: [:sales]))
    end

    test "a provider that is no longer registered is not active", %{admin: admin} do
      {:ok, _setting} = Payments.activate(:simulator, admin)
      Application.put_env(:mercator, :payment_providers, [])
      on_exit(fn -> Application.put_env(:mercator, :payment_providers, [Simulator]) end)

      refute Payments.online?()
    end

    test "payments made earlier find their provider by key" do
      assert Payments.provider("simulator") == Simulator
      assert Payments.provider(:simulator) == Simulator
      assert Payments.provider("mollie") == nil
    end
  end

  describe "simulator" do
    defp start do
      {:ok, payment} =
        Simulator.create_payment(%{number: "BH-2026-00001"}, Decimal.new("129.90"), %{
          return: "/account/orders/BH-2026-00001/payment",
          webhook: "/payments/simulator/webhook"
        })

      payment
    end

    test "a payment is open until it is decided on the simulator page" do
      payment = start()

      assert payment.status == :open
      assert payment.checkout_url =~ ~r{^https?://.+/payments/simulator/#{payment.id}$}
      assert {:ok, %{status: :open}} = Simulator.fetch_payment(payment.id)

      assert {:ok, %{status: :paid, method: "eps"}} = Simulator.complete(payment.id, :paid, "eps")
      assert {:ok, %{status: :paid}} = Simulator.fetch_payment(payment.id)

      # decided once
      assert {:error, :not_open} = Simulator.complete(payment.id, :failed)
    end

    test "only paid payments are refunded" do
      payment = start()
      assert {:error, :not_paid} = Simulator.refund(payment.id, payment.amount)

      {:ok, _paid} = Simulator.complete(payment.id, :paid)
      assert :ok = Simulator.refund(payment.id, payment.amount)
      assert {:ok, %{status: :refunded}} = Simulator.fetch_payment(payment.id)
    end

    test "paying by card: test cards decide, the rest is checked" do
      payment = start()

      assert {:error, :unknown_card} = Simulator.pay_by_card(payment.id, "1234", "12/39", "123")

      assert {:error, :invalid_expiry} =
               Simulator.pay_by_card(payment.id, "4242424242424242", "13/39", "123")

      assert {:error, :invalid_expiry} =
               Simulator.pay_by_card(payment.id, "4242424242424242", "01/20", "123")

      assert {:error, :invalid_cvc} =
               Simulator.pay_by_card(payment.id, "4242424242424242", "12/39", "12")

      assert {:ok, %{status: :open}} = Simulator.fetch_payment(payment.id)

      assert {:ok, %{status: :failed}} =
               Simulator.pay_by_card(payment.id, "4000 0000 0000 0002", "12/39", "123")

      assert {:ok, %{status: :paid, method: "creditcard"}} =
               Simulator.pay_by_card(start().id, "4242 4242 4242 4242", "12/39", "1234")
    end

    test "EPS: test login and TANs" do
      assert :ok = Simulator.eps_login("12345678", "1234")
      assert {:error, :invalid_login} = Simulator.eps_login("12345678", "0000")

      payment = start()
      assert {:error, :unknown_tan} = Simulator.pay_by_eps(payment.id, "111111")
      assert {:ok, %{status: :failed}} = Simulator.pay_by_eps(payment.id, "000000")
      assert {:ok, %{status: :paid, method: "eps"}} = Simulator.pay_by_eps(start().id, "123456")
    end

    test "unknown payments" do
      assert {:error, :not_found} = Simulator.fetch_payment("sim_nothing")
    end
  end
end
