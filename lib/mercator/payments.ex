defmodule Mercator.Payments do
  @moduledoc """
  Online payment (phase 7, docs/payment-design.md): the payment providers
  of this deployment and the active one.

  Providers are registered per deployment in config, with their credentials
  from the environment:

      config :mercator, :payment_providers, [Mercator.Payments.Mollie]

  Administrators only switch between them (or switch online payment off);
  the choice is the runtime setting `"payment_provider"`. A payment keeps
  the provider it was started with, so switching does not affect open
  payments.
  """
  use Gettext, backend: MercatorWeb.Gettext
  use MercatorWeb, :verified_routes

  require Ash.Query
  require Logger

  alias Mercator.Operations.{Incidents, Settings}
  alias Mercator.Sales
  alias Mercator.Sales.{OnlinePayment, Order}

  @setting "payment_provider"
  @unpaid_states [:placed, :confirmed]

  @doc "The registered provider modules, in config order."
  def providers, do: Application.get_env(:mercator, :payment_providers, [])

  @doc "The provider module with this key (also for payments made earlier), or nil."
  def provider(key) do
    key = to_string(key)
    Enum.find(providers(), &(to_string(&1.key()) == key))
  end

  @doc """
  The active provider module: the one chosen in the back office, if it is
  registered and available. nil means no online payment.
  """
  def active do
    case Settings.get(@setting) do
      %{"key" => key} when is_binary(key) ->
        with provider when not is_nil(provider) <- provider(key),
             true <- provider.available?() do
          provider
        else
          _ -> nil
        end

      _none ->
        nil
    end
  end

  @doc "Whether customers can pay online right now."
  def online?, do: active() != nil

  @doc """
  Switches the active provider (by key), or off with nil. Administrators
  only; the provider must be registered and available.
  """
  def activate(nil, actor), do: Settings.put(@setting, %{"key" => nil}, actor)

  def activate(key, actor) do
    case provider(key) do
      nil ->
        {:error, :unknown_provider}

      provider ->
        if provider.available?(),
          do: Settings.put(@setting, %{"key" => to_string(provider.key())}, actor),
          else: {:error, :not_available}
    end
  end

  # --- paying an order ---

  @doc """
  Whether an order can be paid online now: paid online, not yet paid, not
  cancelled, and a provider is active.
  """
  def payable?(%Order{payment_method: :online, state: state} = order)
      when state in @unpaid_states,
      do: online?() and not paid?(order)

  def payable?(_order), do: false

  @doc """
  Starts a payment of the order's total with the active provider. Returns
  `{:ok, checkout_url}` (where the customer pays) or `{:error, reason}`;
  provider errors are reported as incidents.
  """
  def start(%Order{} = order) do
    with true <- payable?(order) || {:error, :not_payable},
         provider = active(),
         urls = %{
           return: url(~p"/account/orders/#{order.number}/payment"),
           webhook: url(~p"/payments/#{provider.key()}/webhook")
         },
         {:ok, payment} <- create_at_provider(provider, order, urls),
         {:ok, _online_payment} <-
           Ash.create(
             OnlinePayment,
             %{
               order_id: order.id,
               provider: to_string(provider.key()),
               provider_id: payment.id,
               status: payment.status,
               amount: order.gross,
               checkout_url: payment.checkout_url,
               dashboard_url: payment[:dashboard_url]
             },
             action: :start,
             authorize?: false
           ) do
      {:ok, payment.checkout_url}
    end
  end

  defp create_at_provider(provider, order, urls) do
    case provider.create_payment(order, order.gross, urls) do
      {:ok, payment} ->
        {:ok, payment}

      {:error, reason} ->
        report(order, :start_failed, reason)
        {:error, :provider}
    end
  end

  @doc """
  Asks the provider for the current status of the order's latest payment
  and applies it (see `sync/1`); for the page the customer comes back to.
  Returns the payment, or nil if the order has none.
  """
  def sync_latest(%Order{} = order) do
    case latest(order) do
      nil -> nil
      payment -> sync(payment)
    end
  end

  @doc "The order's most recent payment attempt, or nil."
  def latest(%Order{id: order_id}) do
    OnlinePayment
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  @doc """
  A provider reports a change of a payment (its webhook): `provider_id` is
  its id there. The status is always fetched from the provider, never taken
  from the request. Unknown payments are reported as incidents.
  """
  def notify(provider_key, provider_id) do
    OnlinePayment
    |> Ash.Query.filter(provider == ^to_string(provider_key) and provider_id == ^provider_id)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil ->
        Incidents.in_shop_locale(fn ->
          Incidents.report(%{
            kind: :payment,
            title: gettext("Notification about an unknown payment"),
            description:
              gettext("A payment provider reported a payment this shop does not know."),
            details: "#{provider_key} #{provider_id}"
          })
        end)

        {:error, :unknown_payment}

      payment ->
        {:ok, sync(payment)}
    end
  end

  @doc """
  Fetches the payment's status from its provider and stores it. A payment
  that became paid marks the order paid (once); a wrong amount or a payment
  for a cancelled order is reported as an incident. Returns the payment.
  """
  def sync(%OnlinePayment{} = payment) do
    with provider when not is_nil(provider) <- provider(payment.provider),
         {:ok, remote} <- provider.fetch_payment(payment.provider_id) do
      payment
      |> store(remote)
      |> settle()
    else
      nil ->
        payment

      {:error, reason} ->
        order = Ash.get!(Order, payment.order_id, authorize?: false)
        report(order, :fetch_failed, reason)
        payment
    end
  end

  defp store(payment, remote) do
    changes =
      %{
        status: remote.status,
        method: remote[:method],
        dashboard_url: remote[:dashboard_url] || payment.dashboard_url
      }

    if Map.take(payment, Map.keys(changes)) == changes do
      payment
    else
      Ash.update!(payment, changes, action: :set_status, authorize?: false)
    end
  end

  defp settle(%OnlinePayment{status: :paid} = payment) do
    order = Ash.get!(Order, payment.order_id, authorize?: false)

    cond do
      not Decimal.equal?(payment.amount, order.gross) ->
        report(order, :amount_differs, "paid #{payment.amount}, order #{order.gross}")

      order.state == :cancelled ->
        report(order, :cancelled_order_paid, "payment #{payment.provider_id}")

      order.state in @unpaid_states ->
        Sales.mark_order_paid!(
          order,
          %{note: paid_note(payment), notify: false},
          authorize?: false
        )

      true ->
        :already_paid
    end

    payment
  end

  defp settle(payment), do: payment

  # order events are read by staff: in the shop's language
  defp paid_note(payment), do: Incidents.in_shop_locale(fn -> paid_text(payment) end)

  defp paid_text(%{method: nil}), do: gettext("Paid online.")
  defp paid_text(%{method: method}), do: gettext("Paid online (%{method}).", method: method)

  defp paid?(%Order{id: order_id}) do
    OnlinePayment
    |> Ash.Query.filter(order_id == ^order_id and status == :paid)
    |> Ash.exists?(authorize?: false)
  end

  defp report(order, problem, reason) do
    Logger.error("Payment problem with order #{order.number}: #{problem}: #{inspect(reason)}")

    Incidents.in_shop_locale(fn ->
      Incidents.report(%{
        kind: :payment,
        title: title(problem),
        description: description(problem, order),
        details: if(is_binary(reason), do: reason, else: inspect(reason)),
        order_id: order.id,
        customer_id: order.user_id
      })
    end)
  end

  defp title(:start_failed), do: gettext("A payment could not be started")
  defp title(:fetch_failed), do: gettext("A payment status could not be fetched")
  defp title(:amount_differs), do: gettext("Paid amount differs from the order total")
  defp title(:cancelled_order_paid), do: gettext("Payment for a cancelled order")

  defp description(:cancelled_order_paid, order),
    do:
      gettext("The customer paid the cancelled order %{number}; the payment should be refunded.",
        number: order.number
      )

  defp description(:start_failed, order),
    do:
      gettext("The customer could not pay order %{number} online; it is waiting for payment.",
        number: order.number
      )

  defp description(_problem, order),
    do: gettext("Please check the payment of order %{number}.", number: order.number)
end
