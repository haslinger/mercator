defmodule Mercator.Operations.Incident do
  @moduledoc """
  Something in the shop went wrong and someone should look into it (#105).

  Reported by the system (`reported_by` empty, see
  `Mercator.Operations.Incidents`) or by staff (#107). An incident may point
  to the customer, order, offer or conversation it concerns. The same
  problem reported again while its incident is open counts up
  `occurrences` instead of creating a new one (same `fingerprint`).

  States: `open` → `resolved` (with a resolution) → `open` again.

  Administrators see all incidents; sales staff those about a customer,
  order, offer or conversation, and those they reported (#106).
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Mercator.Accounts.Checks.ActorHasRole

  @kinds [:manual, :pdf, :email, :job, :payment, :other]

  postgres do
    table "incidents"
    repo Mercator.Repo

    references do
      reference :customer, on_delete: :nilify
      reference :order, on_delete: :nilify
      reference :offer, on_delete: :nilify
      reference :conversation, on_delete: :nilify
      reference :reported_by, on_delete: :nilify
      reference :resolved_by, on_delete: :nilify
    end

    custom_indexes do
      index [:state]
      index [:fingerprint]
    end
  end

  state_machine do
    initial_states [:open]
    default_initial_state :open

    transitions do
      transition :resolve, from: :open, to: :resolved
      transition :reopen, from: :resolved, to: :open
    end
  end

  actions do
    defaults [:read]

    create :report do
      description "The system reports a problem (see Mercator.Operations.Incidents.report/1)."

      accept [
        :kind,
        :title,
        :description,
        :details,
        :fingerprint,
        :customer_id,
        :order_id,
        :offer_id,
        :conversation_id
      ]

      change set_attribute(:last_occurred_at, &DateTime.utc_now/0)
    end

    create :create do
      description "Staff record an incident by hand (#107)."
      primary? true
      accept [:title, :description, :customer_id, :order_id, :offer_id, :conversation_id]
      change set_attribute(:kind, :manual)
      change set_attribute(:last_occurred_at, &DateTime.utc_now/0)
      change relate_actor(:reported_by)
    end

    read :search do
      description "Back office list: filter by state and kind, newest activity first."
      argument :state, :atom
      argument :kind, :atom

      filter expr(is_nil(^arg(:state)) or state == ^arg(:state))
      filter expr(is_nil(^arg(:kind)) or kind == ^arg(:kind))
      prepare build(sort: [last_occurred_at: :desc])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    update :update do
      primary? true
      accept [:title, :description, :resolution]
    end

    update :recur do
      description "The same problem happened again while the incident is open."
      accept [:details]
      change atomic_update(:occurrences, expr(occurrences + 1))
      change set_attribute(:last_occurred_at, &DateTime.utc_now/0)
    end

    update :resolve do
      description "Someone fixed it and writes down how."
      require_atomic? false
      accept [:resolution]
      validate present(:resolution)
      change transition_state(:resolved)
      change set_attribute(:resolved_at, &DateTime.utc_now/0)
      change relate_actor(:resolved_by)
    end

    update :reopen do
      description "It is not fixed after all."
      require_atomic? false
      change transition_state(:open)
      change set_attribute(:resolved_at, nil)
      change set_attribute(:resolved_by_id, nil)
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end

    # sales staff (both policies apply): incidents about customers and their
    # business, and the ones they reported (#106)
    policy action_type([:read, :update]) do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end

    policy action_type([:read, :update]) do
      authorize_if expr(not is_nil(customer_id))
      authorize_if expr(not is_nil(order_id))
      authorize_if expr(not is_nil(offer_id))
      authorize_if expr(not is_nil(conversation_id))
      authorize_if expr(reported_by_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :kind, :atom do
      description "Where it comes from: manual (staff), pdf, email, job, payment, other."
      allow_nil? false
      default :other
      public? true
      constraints one_of: @kinds
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 200, trim?: true
    end

    attribute :description, :string do
      description "What happened, in words staff understand."
      public? true
      constraints max_length: 10_000
    end

    attribute :details, :string do
      description "Technical details (error message, job arguments) for whoever fixes the cause."
      public? true
      constraints max_length: 20_000
    end

    attribute :resolution, :string do
      description "What was done about it."
      public? true
      constraints max_length: 10_000
    end

    attribute :fingerprint, :string do
      description "Identifies the same problem, so a recurrence counts up an open incident."
      public? true
      constraints max_length: 500
    end

    attribute :occurrences, :integer, allow_nil?: false, default: 1, public?: true
    attribute :last_occurred_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :resolved_at, :utc_datetime_usec, public?: true
    timestamps()
  end

  relationships do
    belongs_to :customer, Mercator.Accounts.User, public?: true
    belongs_to :order, Mercator.Sales.Order, public?: true
    belongs_to :offer, Mercator.Consulting.Offer, public?: true
    belongs_to :conversation, Mercator.Consulting.Conversation, public?: true
    belongs_to :reported_by, Mercator.Accounts.User, public?: true
    belongs_to :resolved_by, Mercator.Accounts.User, public?: true
  end

  @doc "The kinds of incidents."
  def kinds, do: @kinds
end
