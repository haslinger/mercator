defmodule Mercator.Sales.Basket do
  @moduledoc """
  A basket of a visitor (`session_token`) or a signed-in user (`user_id`).
  Prices are not stored; they are calculated live (`Mercator.Sales.BasketPricing`).
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "baskets"
    repo Mercator.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: [:session_token, :user_id]]
  end

  # Baskets are only reached through Mercator.Sales.Baskets, which scopes to
  # the owner (session token or user) and runs without an actor.
  policies do
    policy always() do
      authorize_if expr(not is_nil(user_id) and user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :session_token, :string, public?: true, sensitive?: true
    timestamps()
  end

  relationships do
    belongs_to :user, Mercator.Accounts.User, public?: true

    has_many :items, Mercator.Sales.BasketItem do
      sort inserted_at: :asc
      public? true
    end
  end

  identities do
    identity :unique_session_token, [:session_token]
    identity :unique_user, [:user_id]
  end
end
