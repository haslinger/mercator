defmodule Mercator.Payments.Provider do
  @moduledoc """
  A payment provider (docs/payment-design.md, section 2): Mollie and the
  simulator. The shop talks to providers only through these callbacks;
  statuses are mapped to `t:status/0`.
  """

  @type status :: :open | :pending | :paid | :failed | :canceled | :expired | :refunded

  @type payment :: %{
          required(:id) => String.t(),
          required(:status) => status(),
          optional(:checkout_url) => String.t(),
          optional(:amount) => Decimal.t(),
          optional(:method) => String.t() | nil,
          optional(:dashboard_url) => String.t() | nil
        }

  @doc "The key stored with payments and in the setting, e.g. `:mollie`."
  @callback key() :: atom()

  @doc "The name shown in the back office."
  @callback name() :: String.t()

  @doc "Whether the provider can be used: its credentials are configured."
  @callback available?() :: boolean()

  @doc "What is missing when it is not available (for the back office), or nil."
  @callback setup_hint() :: String.t() | nil

  @doc """
  Starts a payment of `amount` (gross EUR) for an order. `urls` holds
  `:return` (where the customer comes back) and `:webhook` (where the
  provider reports status changes). Returns the payment with its
  `:checkout_url`.
  """
  @callback create_payment(
              order :: map(),
              amount :: Decimal.t(),
              urls :: %{return: String.t(), webhook: String.t()}
            ) :: {:ok, payment()} | {:error, term()}

  @doc "The current state of a payment, asked from the provider."
  @callback fetch_payment(id :: String.t()) :: {:ok, payment()} | {:error, term()}

  @doc "Refunds the amount of a paid payment (#113: full refunds)."
  @callback refund(id :: String.t(), amount :: Decimal.t()) :: :ok | {:error, term()}
end
