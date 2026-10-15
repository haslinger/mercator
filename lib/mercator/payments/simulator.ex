defmodule Mercator.Payments.Simulator do
  @moduledoc """
  A payment provider without a provider (docs/payment-design.md): for
  development, the tests and the demo. Its "payment page" is part of the
  shop (`/payments/simulator/:id`), where one chooses whether the payment
  succeeds, fails or is cancelled.

  Payments live in memory (an ETS table owned by this process), so they are
  gone after a restart; the shop's own record (`OnlinePayment`) stays.
  """
  @behaviour Mercator.Payments.Provider

  use GenServer
  use Gettext, backend: MercatorWeb.Gettext

  @table __MODULE__
  @outcomes [:paid, :failed, :canceled, :expired]

  @impl Mercator.Payments.Provider
  def key, do: :simulator

  @impl Mercator.Payments.Provider
  def name, do: gettext("Simulator (no real payment)")

  @impl Mercator.Payments.Provider
  def available?, do: :ets.whereis(@table) != :undefined

  @impl Mercator.Payments.Provider
  def setup_hint, do: nil

  @impl Mercator.Payments.Provider
  def create_payment(order, amount, urls) do
    id = "sim_" <> Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)

    payment = %{
      id: id,
      status: :open,
      amount: amount,
      method: nil,
      order_number: order.number,
      return_url: urls.return,
      checkout_url: "/payments/simulator/#{id}"
    }

    :ets.insert(@table, {id, payment})
    {:ok, payment}
  end

  @impl Mercator.Payments.Provider
  def fetch_payment(id) do
    case :ets.lookup(@table, id) do
      [{^id, payment}] -> {:ok, payment}
      [] -> {:error, :not_found}
    end
  end

  @impl Mercator.Payments.Provider
  def refund(id, _amount) do
    case fetch_payment(id) do
      {:ok, %{status: :paid} = payment} ->
        :ets.insert(@table, {id, %{payment | status: :refunded}})
        :ok

      {:ok, _not_paid} ->
        {:error, :not_paid}

      error ->
        error
    end
  end

  @doc "The outcomes one can choose on the simulator page."
  def outcomes, do: @outcomes

  @doc """
  Decides an open payment (the simulator page): `:paid` (with a payment
  method such as `"creditcard"`), `:failed`, `:canceled` or `:expired`.
  """
  def complete(id, outcome, method \\ "creditcard") when outcome in @outcomes do
    case fetch_payment(id) do
      {:ok, %{status: :open} = payment} ->
        payment = %{payment | status: outcome, method: if(outcome == :paid, do: method)}
        :ets.insert(@table, {id, payment})
        {:ok, payment}

      {:ok, _decided} ->
        {:error, :not_open}

      error ->
        error
    end
  end

  # --- the process owning the table ---

  @doc false
  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl GenServer
  def init(nil) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, nil}
  end
end
