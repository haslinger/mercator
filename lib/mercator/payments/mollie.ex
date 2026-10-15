defmodule Mercator.Payments.Mollie do
  @moduledoc """
  Mollie as payment provider (docs/payment-design.md, phase 7 step 3),
  through its REST API v2 with `Req` (no SDK).

  The API key comes from `MOLLIE_API_KEY` (runtime.exs): a `test_…` key
  only simulates payments (Mollie's test page lets one choose the outcome),
  a `live_…` key takes real money. Without a key the provider is not
  available.

  Mollie reports status changes to the webhook with only the payment id;
  the status is always fetched here with the key. Mollie does not accept a
  webhook URL it cannot reach (e.g. `localhost`), so in development the
  payment is created without one and only the return page syncs it.

      config :mercator, Mercator.Payments.Mollie,
        api_key: "test_…",
        # tests: req_options: [plug: {Req.Test, Mercator.Payments.Mollie}]
        req_options: []
  """
  @behaviour Mercator.Payments.Provider

  use Gettext, backend: MercatorWeb.Gettext

  @base_url "https://api.mollie.com/v2"

  @statuses %{
    "open" => :open,
    "pending" => :pending,
    "authorized" => :pending,
    "paid" => :paid,
    "failed" => :failed,
    "canceled" => :canceled,
    "expired" => :expired
  }

  @impl true
  def key, do: :mollie

  @impl true
  def name do
    if test_mode?(), do: gettext("Mollie (test mode)"), else: "Mollie"
  end

  @impl true
  def available?, do: api_key() != nil

  @impl true
  def setup_hint do
    if available?(),
      do: nil,
      else: gettext("Set MOLLIE_API_KEY in the server's .env (a test_… key for testing).")
  end

  @doc "Whether the API key is a test key (no real money)."
  def test_mode?, do: String.starts_with?(api_key() || "", "test_")

  @impl true
  def create_payment(order, amount, urls) do
    body =
      %{
        amount: money(amount),
        description: description(order),
        redirectUrl: urls.return,
        metadata: %{order_number: order.number},
        locale: locale(order)
      }
      |> maybe_put(:webhookUrl, public_url(urls.webhook))

    with {:ok, payment} <- request(:post, "/payments", body) do
      {:ok, to_payment(payment)}
    end
  end

  @impl true
  def fetch_payment(id) do
    with {:ok, payment} <- request(:get, "/payments/#{URI.encode(id)}") do
      {:ok, to_payment(payment)}
    end
  end

  @impl true
  def refund(id, amount) do
    with {:ok, _refund} <-
           request(:post, "/payments/#{URI.encode(id)}/refunds", %{amount: money(amount)}) do
      :ok
    end
  end

  # --- mapping ---

  defp to_payment(payment) do
    amount = decimal(payment["amount"])

    %{
      id: payment["id"],
      status: status(payment, amount),
      amount: amount,
      method: payment["method"],
      checkout_url: get_in(payment, ["_links", "checkout", "href"])
    }
  end

  # Mollie keeps a refunded payment "paid" and counts the refunded amount
  defp status(%{"status" => "paid", "amountRefunded" => refunded}, amount) when amount != nil do
    if Decimal.compare(decimal(refunded) || Decimal.new(0), amount) == :lt,
      do: :paid,
      else: :refunded
  end

  defp status(%{"status" => status}, _amount), do: Map.get(@statuses, status, :pending)

  defp money(amount),
    do: %{currency: "EUR", value: amount |> Decimal.round(2) |> Decimal.to_string(:normal)}

  defp decimal(%{"value" => value}) when is_binary(value), do: Decimal.new(value)
  defp decimal(_other), do: nil

  # shown on the customer's statement and in Mollie's dashboard
  defp description(order), do: "#{Mercator.Brand.name()} #{order.number}"

  defp locale(%{locale: "en"}), do: "en_US"
  defp locale(_order), do: "de_AT"

  # Mollie refuses webhook URLs it cannot reach
  defp public_url(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host} when host not in [nil, "localhost"] -> url
      _local -> nil
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # --- HTTP ---

  defp request(method, path, body \\ nil) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        [method: method, url: base_url() <> path, auth: {:bearer, key}, retry: false]
        |> then(&if(body, do: Keyword.put(&1, :json, body), else: &1))
        |> Keyword.merge(config(:req_options, []))
        |> Req.request()
        |> handle_response()
    end
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, {:http, status, error_detail(body)}}

  defp handle_response({:error, exception}), do: {:error, exception}

  defp error_detail(%{"detail" => detail}), do: detail
  defp error_detail(body), do: body

  defp api_key do
    case config(:api_key) do
      key when is_binary(key) and key != "" -> key
      _none -> nil
    end
  end

  defp base_url, do: config(:base_url, @base_url)

  defp config(key, default \\ nil),
    do: :mercator |> Application.get_env(__MODULE__, []) |> Keyword.get(key, default)
end
