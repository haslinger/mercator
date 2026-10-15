defmodule Mercator.Sales.OnlinePayment do
  @moduledoc """
  One attempt to pay an order online (docs/payment-design.md, section 3):
  the provider it was made with (kept when the active provider is switched),
  the provider's id and the last known status. An order can have several
  attempts after failed or cancelled ones; at most one is paid.

  Created and updated by the system (`Mercator.Payments`); customers see
  them through their order, staff in the back office.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  @statuses [:open, :pending, :paid, :failed, :canceled, :expired, :refunded]

  postgres do
    table "online_payments"
    repo Mercator.Repo

    references do
      reference :order, on_delete: :delete
    end

    custom_indexes do
      index [:order_id]
    end
  end

  actions do
    defaults [:read]

    create :start do
      accept [:order_id, :provider, :provider_id, :status, :amount, :checkout_url, :dashboard_url]
    end

    update :set_status do
      description "The status the provider reported, with the payment method used."
      accept [:status, :method, :dashboard_url]
    end

    update :mark_refunded do
      accept []
      change set_attribute(:status, :refunded)
      change set_attribute(:refunded_at, &DateTime.utc_now/0)
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(order.user_id == ^actor(:id))
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :string do
      description "The provider's key, e.g. mollie or simulator."
      allow_nil? false
      public? true
    end

    attribute :provider_id, :string do
      description "The payment's id at the provider."
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :open
      public? true
      constraints one_of: @statuses
    end

    attribute :amount, :decimal, allow_nil?: false, public?: true

    attribute :method, :string do
      description "How the customer paid, as the provider reports it (creditcard, eps, …)."
      public? true
    end

    attribute :checkout_url, :string, public?: true

    attribute :dashboard_url, :string do
      description "The payment in the provider's dashboard, for staff (if the provider has one)."
      public? true
    end

    attribute :refunded_at, :utc_datetime_usec, public?: true
    timestamps()
  end

  relationships do
    belongs_to :order, Mercator.Sales.Order, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_provider_id, [:provider, :provider_id]
  end

  @doc "The payment statuses."
  def statuses, do: @statuses
end
