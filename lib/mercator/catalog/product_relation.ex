defmodule Mercator.Catalog.ProductRelation do
  @moduledoc """
  A relation from one product to another (#2 in catalog-design.md): related
  products, accessories or recommendations, with an optional reason.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "product_relations"
    repo Mercator.Repo

    references do
      reference :product, on_delete: :delete
      reference :related_product, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:product_id, :related_product_id, :kind, :reason, :position]
    end

    update :update do
      primary? true
      accept [:reason, :position]
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
      authorize_if expr(product.state == :active and related_product.state == :active)
    end
  end

  validations do
    validate {Mercator.Catalog.Validations.NotSelfRelated, []}, on: [:create]
  end

  attributes do
    uuid_primary_key :id
    attribute :kind, Mercator.Catalog.RelationKind, allow_nil?: false, public?: true
    attribute :reason, Mercator.Translated, public?: true, constraints: [max_length: 300]
    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    timestamps()
  end

  relationships do
    belongs_to :product, Mercator.Catalog.Product, allow_nil?: false, public?: true
    belongs_to :related_product, Mercator.Catalog.Product, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_relation, [:product_id, :related_product_id, :kind]
  end
end
