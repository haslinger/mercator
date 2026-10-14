defmodule Mercator.Consulting.Conversation do
  @moduledoc """
  A conversation between a customer and a consultant (docs/guided-selling-design.md).

  The customer is a signed-in user or a visitor (browser session token,
  #94; moved to the user at sign-in). States: `waiting` (no consultant
  yet), `active`, `closed`.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Consulting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "conversations"
    repo Mercator.Repo

    references do
      reference :customer, on_delete: :delete
      reference :consultant, on_delete: :nilify
      reference :product, on_delete: :nilify
    end

    custom_indexes do
      index [:session_token]
      index [:state]
    end
  end

  state_machine do
    initial_states [:waiting]
    default_initial_state :waiting

    transitions do
      transition :take, from: [:waiting, :active], to: :active
      transition :close, from: [:waiting, :active], to: :closed
    end
  end

  actions do
    defaults [:read]

    create :start do
      accept [:customer_id, :session_token, :subject, :page, :product_id]
    end

    update :take do
      description "A consultant takes the conversation (or takes it over)."
      accept []
      require_atomic? false
      change transition_state(:active)
      change relate_actor(:consultant)
    end

    update :close do
      accept []
      change transition_state(:closed)
    end

    update :touch do
      description "Marks new activity (a message)."
      accept []
      change set_attribute(:last_message_at, &DateTime.utc_now/0)
    end

    update :request_callback do
      description "Nobody answered in time (#95): the customer asks to be contacted."
      accept [:callback_kind, :callback_contact]
      require_atomic? false
      validate present([:callback_kind, :callback_contact])
      validate Mercator.Consulting.Validations.CallbackContact
      change set_attribute(:callback_requested_at, &DateTime.utc_now/0)
    end

    update :move_to_user do
      description "At sign-in, a visitor's conversation becomes the user's."
      accept [:customer_id]
      change set_attribute(:session_token, nil)
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy always() do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :session_token, :string do
      description "Owner while the customer is a visitor (#94)."
      sensitive? true
    end

    attribute :subject, :string, public?: true, constraints: [max_length: 200]

    attribute :page, :string do
      description "The shop page the conversation was started from."
      public? true
      constraints max_length: 500
    end

    attribute :last_message_at, :utc_datetime_usec, public?: true

    attribute :callback_kind, :atom do
      description "How the customer wants to be contacted when nobody answered (#95)."
      public? true
      constraints one_of: [:email, :phone]
    end

    attribute :callback_contact, :string,
      public?: true,
      constraints: [max_length: 200, trim?: true]

    attribute :callback_requested_at, :utc_datetime_usec, public?: true
    timestamps()
  end

  relationships do
    belongs_to :customer, Mercator.Accounts.User, public?: true
    belongs_to :consultant, Mercator.Accounts.User, public?: true
    belongs_to :product, Mercator.Catalog.Product, public?: true

    has_many :messages, Mercator.Consulting.Message do
      sort inserted_at: :asc
      public? true
    end
  end
end
