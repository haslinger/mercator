defmodule Mercator.Catalog.ProductProperty do
  @moduledoc "The value of a property for a product (Rails: Value)."
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Catalog.Validations.ValueMatchesKind

  @values [:text_value, :number_value, :boolean_value]

  postgres do
    table "product_properties"
    repo Mercator.Repo

    references do
      reference :product, on_delete: :delete
      reference :property, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:product_id, :property_id | @values]
      validate ValueMatchesKind
    end

    update :update do
      primary? true
      require_atomic? false
      accept @values
      validate ValueMatchesKind
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
      authorize_if expr(product.state == :active)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :text_value, Mercator.Translated, public?: true, constraints: [max_length: 200]
    attribute :number_value, :decimal, public?: true
    attribute :boolean_value, :boolean, public?: true
    timestamps()
  end

  relationships do
    belongs_to :product, Mercator.Catalog.Product, allow_nil?: false, public?: true
    belongs_to :property, Mercator.Catalog.Property, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_product_property, [:product_id, :property_id]
  end
end
