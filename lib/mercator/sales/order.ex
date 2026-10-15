defmodule Mercator.Sales.Order do
  @moduledoc """
  An order: an immutable snapshot of the basket at checkout, with addresses,
  shipping and payment method, totals and the accepted GTC version
  (checkout-design.md, sections 3 and 4). Created by `Mercator.Sales.Checkout`.

  The number is `<prefix>-<year>-<sequence>` (#68), gap-free per year, with
  the prefix from the brand config (`:order_prefix`).
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Sales.{PaymentMethod, ShippingMethod}

  postgres do
    table "orders"
    repo Mercator.Repo

    references do
      reference :user, on_delete: :restrict
      reference :offer, on_delete: :nilify
    end
  end

  state_machine do
    initial_states [:placed]
    default_initial_state :placed

    transitions do
      transition :confirm, from: :placed, to: :confirmed
      transition :mark_paid, from: [:placed, :confirmed, :shipped], to: :paid
      transition :ship, from: [:placed, :confirmed, :paid], to: :shipped
      transition :complete, from: [:paid, :shipped], to: :completed
      transition :cancel, from: [:placed, :confirmed, :paid], to: :cancelled
    end
  end

  actions do
    defaults [:read]

    create :place do
      description "Creates the order from a checkout snapshot (see Mercator.Sales.Checkout)."

      accept [
        :email,
        :locale,
        :billing_address,
        :shipping_address,
        :shipping_method,
        :payment_method,
        :shipping_gross,
        :shipping_estimate,
        :goods_gross,
        :net,
        :vat,
        :gross,
        :vat_lines,
        :gtc_version,
        :gtc_accepted_at,
        :note,
        :offer_id
      ]

      argument :items, {:array, :map}, allow_nil?: false

      change relate_actor(:user)
      change Mercator.Sales.Changes.AssignOrderNumber
      change manage_relationship(:items, type: :create)
    end

    read :mine do
      description "The actor's orders, newest first."
      filter expr(user_id == ^actor(:id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :by_number do
      get_by [:number]
    end

    read :search do
      description "Back office list: filter by state, period and text, newest first."

      argument :state, :atom
      argument :from, :date
      argument :to, :date
      argument :query, :string

      filter expr(is_nil(^arg(:state)) or state == ^arg(:state))
      prepare Mercator.Sales.Preparations.SearchOrders
      prepare build(sort: [inserted_at: :desc])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    # state changes by staff, each recorded as an OrderEvent with an optional note
    update :confirm do
      require_atomic? false
      argument :note, :string
      argument :notify, :boolean, default: true, description: "Email the customer (#74)."

      argument :shipping_gross, :decimal,
        description: "Final costs when they were estimated (freight)."

      change Mercator.Sales.Changes.SetFinalShipping
      change transition_state(:confirmed)
      change Mercator.Sales.Changes.RecordStateChange
    end

    for {name, state} <- [mark_paid: :paid, ship: :shipped, complete: :completed] do
      update name do
        require_atomic? false
        argument :note, :string
        argument :notify, :boolean, default: true, description: "Email the customer (#74)."
        change transition_state(state)
        change Mercator.Sales.Changes.RecordStateChange
      end
    end

    update :cancel do
      require_atomic? false
      argument :note, :string, allow_nil?: false, description: "Reason for the cancellation."
      argument :notify, :boolean, default: true, description: "Email the customer (#74)."
      change transition_state(:cancelled)
      change Mercator.Sales.Changes.RestoreStock
      change Mercator.Sales.Changes.RecordStateChange
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action(:place) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end

    policy action_type(:update) do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :string do
      allow_nil? false
      public? true
    end

    attribute :year, :integer, allow_nil?: false
    attribute :sequence, :integer, allow_nil?: false

    attribute :email, :string do
      description "The customer's email address at the time of the order."
      allow_nil? false
      public? true
    end

    attribute :locale, :string do
      description "Language of the customer; used for emails."
      allow_nil? false
      default "de"
      public? true
    end

    attribute :billing_address, :map do
      allow_nil? false
      public? true
    end

    attribute :shipping_address, :map do
      description "Delivery address; nil for pickup."
      public? true
    end

    attribute :shipping_method, ShippingMethod, allow_nil?: false, public?: true
    attribute :payment_method, PaymentMethod, allow_nil?: false, public?: true

    attribute :shipping_gross, :decimal do
      allow_nil? false
      public? true
    end

    attribute :shipping_estimate, :boolean do
      description "The shipping costs are a \"from\" price, to be confirmed by staff (freight)."
      allow_nil? false
      default false
      public? true
    end

    attribute :goods_gross, :decimal, allow_nil?: false, public?: true
    attribute :net, :decimal, allow_nil?: false, public?: true
    attribute :vat, :decimal, allow_nil?: false, public?: true
    attribute :gross, :decimal, allow_nil?: false, public?: true

    attribute :vat_lines, {:array, :map} do
      description ~s(Net and VAT per rate, shipping included: [%{"rate", "net", "vat"}].)
      allow_nil? false
      default []
      public? true
    end

    attribute :gtc_version, :date, allow_nil?: false, public?: true
    attribute :gtc_accepted_at, :utc_datetime_usec, allow_nil?: false, public?: true

    attribute :note, :string do
      description "The customer's note."
      public? true
      constraints max_length: 2000
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Mercator.Accounts.User, allow_nil?: false, public?: true

    belongs_to :offer, Mercator.Consulting.Offer do
      description "The offer this order was placed from (guided selling)."
      public? true
    end

    has_many :items, Mercator.Sales.OrderItem do
      public? true
      sort position: :asc
    end

    has_many :events, Mercator.Sales.OrderEvent do
      public? true
      sort inserted_at: :asc
    end

    has_many :online_payments, Mercator.Sales.OnlinePayment do
      description "Attempts to pay the order online (phase 7)."
      public? true
      sort inserted_at: :asc
    end
  end

  aggregates do
    count :item_count, :items, public?: true
  end

  identities do
    identity :unique_number, [:number]
    identity :unique_sequence, [:year, :sequence]
  end
end
