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
  use MercatorWeb, :verified_routes

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
      # absolute, like a real provider's page
      checkout_url: url(~p"/payments/simulator/#{id}")
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

  # test card numbers (the same as Stripe's) and how a payment with them ends
  @test_cards [{"4242424242424242", :paid}, {"4000000000000002", :failed}]

  @doc "The test cards: `[{number, outcome}]`, shown on the simulator page."
  def test_cards, do: @test_cards

  @doc """
  Pays an open payment by card (the simulator page): a test card decides
  the outcome (`test_cards/0`); any other number is `{:error, :unknown_card}`
  and the payment stays open. Expiry (`MM/YY`, not in the past) and the
  security code (3 or 4 digits) are checked like a real page would.
  """
  def pay_by_card(id, number, expiry, cvc) do
    number = String.replace(number || "", ~r/\D/, "")

    with :ok <- valid_expiry(expiry),
         :ok <- valid_cvc(cvc),
         {:ok, outcome} <- card_outcome(number) do
      complete(id, outcome, "creditcard")
    end
  end

  # EPS: fictional banks (never real bank names) and test credentials
  @eps_banks ["Demo-Bank Waldviertel", "Testbank Alpen", "Musterbank Donau"]
  @eps_login {"12345678", "1234"}
  @eps_tans [{"123456", :paid}, {"000000", :failed}]

  @doc "The fictional banks of the EPS simulation."
  def eps_banks, do: @eps_banks

  @doc "The test login of the simulated online banking: `{user_number, pin}`."
  def eps_test_login, do: @eps_login

  @doc "The test TANs: `[{tan, outcome}]`."
  def eps_tans, do: @eps_tans

  @doc "Checks the login of the simulated online banking."
  def eps_login(user_number, pin) do
    if {String.trim(user_number || ""), String.trim(pin || "")} == @eps_login,
      do: :ok,
      else: {:error, :invalid_login}
  end

  @doc """
  Confirms an EPS transfer with a TAN (after `eps_login/2`): a test TAN
  decides the outcome (`eps_tans/0`); any other is `{:error, :unknown_tan}`
  and the payment stays open.
  """
  def pay_by_eps(id, tan) do
    case List.keyfind(@eps_tans, String.trim(tan || ""), 0) do
      {_tan, outcome} -> complete(id, outcome, "eps")
      nil -> {:error, :unknown_tan}
    end
  end

  defp card_outcome(number) do
    case List.keyfind(@test_cards, number, 0) do
      {^number, outcome} -> {:ok, outcome}
      nil -> {:error, :unknown_card}
    end
  end

  defp valid_expiry(expiry) do
    with [_all, month, year] <- Regex.run(~r/^\s*(\d{2})\s*\/\s*(\d{2})\s*$/, expiry || ""),
         {month, ""} when month in 1..12 <- Integer.parse(month),
         {year, ""} <- Integer.parse(year),
         today = Mercator.Clock.today(),
         false <- {2000 + year, month} < {today.year, today.month} do
      :ok
    else
      _ -> {:error, :invalid_expiry}
    end
  end

  defp valid_cvc(cvc) do
    if Regex.match?(~r/^\s*\d{3,4}\s*$/, cvc || ""), do: :ok, else: {:error, :invalid_cvc}
  end

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

  @doc "Forgets all payments (the nightly demo reset)."
  def clear do
    if available?(), do: :ets.delete_all_objects(@table)
    :ok
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
