defmodule Mercator.Payments.MollieTest do
  # Req.Test stubs are owned by the test process, so this can run async
  use ExUnit.Case, async: true

  alias Mercator.Payments.Mollie

  @order %{number: "2026-0042", locale: "de"}
  @urls %{
    return: "https://shop.example/account/orders/2026-0042/payment",
    webhook: "https://shop.example/payments/mollie/webhook"
  }

  defp payment(attrs) do
    Map.merge(
      %{
        "resource" => "payment",
        "id" => "tr_test123",
        "status" => "open",
        "amount" => %{"currency" => "EUR", "value" => "123.40"},
        "method" => nil,
        "_links" => %{
          "checkout" => %{"href" => "https://www.mollie.com/checkout/test-mode?tr_test123"}
        }
      },
      attrs
    )
  end

  defp stub(fun), do: Req.Test.stub(Mollie, fun)

  describe "create_payment/3" do
    test "creates the payment with amount, description, URLs and language" do
      stub(fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v2/payments"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_dummy"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(body)
        assert body["amount"] == %{"currency" => "EUR", "value" => "123.40"}
        assert body["description"] =~ "2026-0042"
        assert body["redirectUrl"] == @urls.return
        assert body["webhookUrl"] == @urls.webhook
        assert body["metadata"] == %{"order_number" => "2026-0042"}
        assert body["locale"] == "de_AT"

        conn |> Plug.Conn.put_status(201) |> Req.Test.json(payment(%{}))
      end)

      assert {:ok, payment} = Mollie.create_payment(@order, Decimal.new("123.4"), @urls)
      assert payment.id == "tr_test123"
      assert payment.status == :open
      assert payment.checkout_url =~ "mollie.com/checkout"
      assert Decimal.equal?(payment.amount, "123.40")
    end

    test "leaves out a webhook URL Mollie cannot reach (development)" do
      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        refute Map.has_key?(Jason.decode!(body), "webhookUrl")
        conn |> Plug.Conn.put_status(201) |> Req.Test.json(payment(%{}))
      end)

      urls = %{
        return: "http://localhost:4000/x",
        webhook: "http://localhost:4000/payments/mollie/webhook"
      }

      assert {:ok, _payment} = Mollie.create_payment(@order, Decimal.new(10), urls)
    end

    test "returns Mollie's error" do
      stub(fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{"status" => 422, "detail" => "The amount is lower than the minimum"})
      end)

      assert {:error, {:http, 422, "The amount is lower than the minimum"}} =
               Mollie.create_payment(@order, Decimal.new("0.001"), @urls)
    end

    test "returns transport errors" do
      stub(&Req.Test.transport_error(&1, :econnrefused))

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               Mollie.create_payment(@order, Decimal.new(10), @urls)
    end
  end

  describe "fetch_payment/1" do
    test "maps Mollie's statuses to ours" do
      for {mollie, ours} <- [
            {"open", :open},
            {"pending", :pending},
            {"authorized", :pending},
            {"paid", :paid},
            {"failed", :failed},
            {"canceled", :canceled},
            {"expired", :expired}
          ] do
        stub(fn conn ->
          assert conn.method == "GET"
          assert conn.request_path == "/v2/payments/tr_test123"
          Req.Test.json(conn, payment(%{"status" => mollie, "method" => "eps"}))
        end)

        assert {:ok, %{status: ^ours, method: "eps"}} = Mollie.fetch_payment("tr_test123")
      end
    end

    test "a paid payment refunded in full is refunded, in part still paid" do
      for {refunded, status} <- [{"123.40", :refunded}, {"20.00", :paid}] do
        stub(fn conn ->
          Req.Test.json(
            conn,
            payment(%{
              "status" => "paid",
              "amountRefunded" => %{"currency" => "EUR", "value" => refunded}
            })
          )
        end)

        assert {:ok, %{status: ^status}} = Mollie.fetch_payment("tr_test123")
      end
    end
  end

  test "refund/2 refunds the amount" do
    stub(fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/payments/tr_test123/refunds"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"amount" => %{"currency" => "EUR", "value" => "123.40"}}

      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(%{"resource" => "refund", "id" => "re_1"})
    end)

    assert :ok = Mollie.refund("tr_test123", Decimal.new("123.4"))
  end

  test "is available with a key, in test mode for a test key" do
    assert Mollie.available?()
    assert Mollie.test_mode?()
    assert Mollie.setup_hint() == nil
  end
end
