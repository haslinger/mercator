defmodule Mercator.Sales.OrderEvent do
  @moduledoc """
  One state change of an order, with an optional note and the staff member
  who made it (checkout-design.md, section 6). Written by
  `Mercator.Sales.Changes.RecordStateChange` on every transition.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "order_events"
    repo Mercator.Repo

    references do
      reference :order, on_delete: :delete
      reference :user, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:from_state, :to_state, :note, :customer_notified, :order_id, :user_id]
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

    attribute :from_state, :atom, allow_nil?: false, public?: true
    attribute :to_state, :atom, allow_nil?: false, public?: true

    attribute :note, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :customer_notified, :boolean do
      description "Whether the customer was emailed about this change (#74)."
      allow_nil? false
      default false
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :order, Mercator.Sales.Order, allow_nil?: false, public?: true
    belongs_to :user, Mercator.Accounts.User, public?: true
  end
end
