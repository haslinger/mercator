defmodule Mercator.Consulting.Offer do
  @moduledoc """
  An individual offer for a signed-in customer (docs/guided-selling-design.md,
  3.3), made by a consultant, often from a conversation.

  States: `draft` → (`pending_approval` →) `sent` → `accepted` / `expired` /
  `withdrawn`. A sent or expired offer is revised into a new draft with the
  same number and the next `version`; the old one becomes `revised`.

  The number is `<prefix>-A-<year>-<sequence>`, gap-free per year. Totals
  (`net`, `vat`, `gross`, `vat_lines`) are kept up to date by
  `Mercator.Consulting.Offers` whenever items change.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Consulting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Mercator.Accounts.Checks.ActorHasRole

  @customer_states [:sent, :accepted, :expired]

  postgres do
    table "offers"
    repo Mercator.Repo

    references do
      reference :customer, on_delete: :delete
      reference :consultant, on_delete: :nilify
      reference :approved_by, on_delete: :nilify
      reference :conversation, on_delete: :nilify
      reference :previous_offer, on_delete: :nilify
    end

    custom_indexes do
      index [:state]
      index [:customer_id]
    end
  end

  state_machine do
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :submit, from: :draft, to: [:pending_approval, :sent]
      transition :approve, from: :pending_approval, to: :sent
      transition :reject, from: :pending_approval, to: :draft
      transition :withdraw, from: [:draft, :pending_approval, :sent], to: :withdrawn
      transition :expire, from: :sent, to: :expired
      transition :mark_revised, from: [:sent, :expired], to: :revised
      transition :accept, from: :sent, to: :accepted
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "A new offer for a customer; the actor is the consultant."
      accept [:customer_id, :conversation_id, :locale, :valid_until, :discount_percent, :note]
      argument :items, {:array, :map}, default: [], description: "Items of a copied offer."
      change relate_actor(:consultant)
      change Mercator.Consulting.Changes.AssignOfferNumber
      change manage_relationship(:items, type: :create)
    end

    create :revision do
      description "The next version of an offer (see Mercator.Consulting.Offers.revise/2)."

      accept [
        :customer_id,
        :conversation_id,
        :locale,
        :valid_until,
        :discount_percent,
        :note,
        :number,
        :year,
        :sequence,
        :version,
        :previous_offer_id
      ]

      argument :items, {:array, :map}, default: []

      change relate_actor(:consultant)
      change manage_relationship(:items, type: :create)
      change Mercator.Consulting.Changes.MarkPreviousRevised
    end

    read :search do
      description "Back office list: filter by state and customer, newest first."
      argument :state, :atom
      argument :customer_id, :uuid

      filter expr(is_nil(^arg(:state)) or state == ^arg(:state))
      filter expr(is_nil(^arg(:customer_id)) or customer_id == ^arg(:customer_id))
      prepare build(sort: [inserted_at: :desc])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    read :mine do
      description "The actor's offers as a customer: sent, accepted or expired."
      filter expr(customer_id == ^actor(:id) and state in ^@customer_states)
      prepare build(sort: [inserted_at: :desc])
    end

    update :update do
      primary? true
      accept [:valid_until, :discount_percent, :note]
      validate attribute_equals(:state, :draft)
    end

    update :set_totals do
      description "Stores the totals after items changed (Mercator.Consulting.Offers)."
      accept [:net, :vat, :gross, :vat_lines]
    end

    update :submit do
      require_atomic? false
      change Mercator.Consulting.Changes.SubmitOffer
    end

    update :approve do
      description "A sales manager approves the discount (#98); the offer is sent."
      require_atomic? false
      change transition_state(:sent)
      change relate_actor(:approved_by)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
      change set_attribute(:sent_at, &DateTime.utc_now/0)
    end

    update :reject do
      description "A sales manager sends the offer back to the consultant."
      argument :note, :string, allow_nil?: false, constraints: [max_length: 2000]
      change transition_state(:draft)
      change set_attribute(:approval_note, arg(:note))
    end

    update :accept do
      description "The customer orders the offer (in the checkout, see Mercator.Sales.Checkout)."
      require_atomic? false
      validate Mercator.Consulting.Validations.OfferValid
      change transition_state(:accepted)
      change set_attribute(:accepted_at, &DateTime.utc_now/0)
    end

    update :withdraw, change: transition_state(:withdrawn)
    update :expire, change: transition_state(:expired)
    update :mark_revised, change: transition_state(:revised)
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(customer_id == ^actor(:id) and state in ^@customer_states)
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end

    policy action([:approve, :reject]) do
      authorize_if {ActorHasRole, role: :sales_manager}
    end

    policy action(:accept) do
      authorize_if expr(customer_id == ^actor(:id))
    end

    policy action_type([:create, :update]) do
      # restricted to the customer by the policy above
      authorize_if action(:accept)
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :string do
      description "Shared by all versions of an offer."
      allow_nil? false
      public? true
    end

    attribute :year, :integer, allow_nil?: false
    attribute :sequence, :integer, allow_nil?: false

    attribute :version, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :locale, :string do
      description "The customer's language: item texts and the offer document."
      allow_nil? false
      default "de"
      public? true
    end

    attribute :valid_until, :date do
      allow_nil? false
      default &__MODULE__.default_valid_until/0
      public? true
    end

    attribute :discount_percent, :decimal do
      description "Overall discount on all items."
      allow_nil? false
      default Decimal.new(0)
      public? true
      constraints min: 0, max: 100
    end

    attribute :note, :string do
      description "Text for the customer, shown with the offer."
      public? true
      constraints max_length: 4000
    end

    attribute :approval_note, :string do
      description "Why a sales manager sent the offer back."
      public? true
    end

    attribute :net, :decimal, allow_nil?: false, default: Decimal.new(0), public?: true
    attribute :vat, :decimal, allow_nil?: false, default: Decimal.new(0), public?: true
    attribute :gross, :decimal, allow_nil?: false, default: Decimal.new(0), public?: true

    attribute :vat_lines, {:array, :map} do
      description ~s(Net and VAT per rate: [%{"rate", "net", "vat"}].)
      allow_nil? false
      default []
      public? true
    end

    attribute :sent_at, :utc_datetime_usec, public?: true
    attribute :approved_at, :utc_datetime_usec, public?: true
    attribute :accepted_at, :utc_datetime_usec, public?: true
    timestamps()
  end

  relationships do
    belongs_to :customer, Mercator.Accounts.User, allow_nil?: false, public?: true
    belongs_to :consultant, Mercator.Accounts.User, public?: true
    belongs_to :approved_by, Mercator.Accounts.User, public?: true
    belongs_to :conversation, Mercator.Consulting.Conversation, public?: true
    belongs_to :previous_offer, __MODULE__, public?: true

    has_one :order, Mercator.Sales.Order do
      description "The order placed from the accepted offer."
      public? true
    end

    has_many :items, Mercator.Consulting.OfferItem do
      public? true
      sort position: :asc
    end
  end

  identities do
    identity :unique_version, [:number, :version]
  end

  @doc "Days an offer is valid by default (`config :mercator, :offer_validity_days`)."
  def default_valid_until,
    do: Date.add(Mercator.Clock.today(), Application.get_env(:mercator, :offer_validity_days, 30))

  @doc "The discount in percent above which a sales manager approves (#98)."
  def approval_limit,
    do: Decimal.new(Application.get_env(:mercator, :offer_approval_limit, 10))

  @doc "Whether the customer can still order the offer."
  def acceptable?(%{state: :sent, valid_until: date}),
    do: not Date.before?(date, Mercator.Clock.today())

  def acceptable?(_offer), do: false

  @doc "The number as shown, with the version from the second one on: `BH-A-2026-00012/2`."
  def display_number(%{version: 1, number: number}), do: number
  def display_number(%{version: version, number: number}), do: "#{number}/#{version}"
end
