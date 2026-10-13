defmodule Mercator.Catalog.Categorization do
  @moduledoc "Assigns a product to a category, with its position in that category."
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "categorizations"
    repo Mercator.Repo

    references do
      reference :category, on_delete: :delete
      reference :product, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:category_id, :product_id, :position]
    end

    update :update do
      primary? true
      accept [:position]
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    bypass {ActorHasRole, role: :productmanager} do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(product.state == :active and category.state in [:active, :hidden])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :category, Mercator.Catalog.Category do
      allow_nil? false
      public? true
    end

    belongs_to :product, Mercator.Catalog.Product do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_category_product, [:category_id, :product_id]
  end
end
