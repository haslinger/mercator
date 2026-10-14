defmodule Mercator.Consulting.Message do
  @moduledoc "A message in a conversation, from the customer, a consultant or the system."
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Consulting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "conversation_messages"
    repo Mercator.Repo

    references do
      reference :conversation, on_delete: :delete
      reference :sender, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :post do
      accept [:conversation_id, :sender_kind, :sender_id, :body]
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

    attribute :sender_kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:customer, :consultant, :system]
    end

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints max_length: 5000, trim?: true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :conversation, Mercator.Consulting.Conversation, allow_nil?: false, public?: true
    belongs_to :sender, Mercator.Accounts.User, public?: true
  end
end
