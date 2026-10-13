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
        :note
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

    # state changes by staff (back office, step 6)
    update :confirm, change: transition_state(:confirmed)
    update :mark_paid, change: transition_state(:paid)
    update :ship, change: transition_state(:shipped)
    update :complete, change: transition_state(:completed)
    update :cancel, change: transition_state(:cancelled)
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

    has_many :items, Mercator.Sales.OrderItem do
      public? true
      sort position: :asc
    end
  end

  identities do
    identity :unique_number, [:number]
    identity :unique_sequence, [:year, :sequence]
  end
end
