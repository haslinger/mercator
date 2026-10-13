defmodule Mercator.Sales.BasketItem do
  @moduledoc """
  An item in a basket: a variant and a quantity, and for configurable
  products the configuration (`selections`, `config_number`).
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "basket_items"
    repo Mercator.Repo

    references do
      reference :basket, on_delete: :delete
      reference :variant, on_delete: :delete
    end
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:basket_id, :variant_id, :quantity, :selections, :config_number]
    ]

    update :update do
      primary? true
      accept [:quantity]
    end
  end

  policies do
    policy always() do
      authorize_if expr(not is_nil(basket.user_id) and basket.user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      constraints greater_than: 0
    end

    attribute :selections, :map do
      description "Configuration of a configurable product (option key => value)."
      allow_nil? false
      default %{}
      public? true
    end

    attribute :config_number, :string, public?: true
    timestamps()
  end

  relationships do
    belongs_to :basket, Mercator.Sales.Basket, allow_nil?: false, public?: true
    belongs_to :variant, Mercator.Catalog.Variant, allow_nil?: false, public?: true
  end
end
