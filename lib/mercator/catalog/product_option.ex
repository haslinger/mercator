defmodule Mercator.Catalog.ProductOption do
  @moduledoc """
  An option of a configurable product (#39, #55): a choice such as the wood
  species, or a number such as the length in mm.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  @editable [:name, :role, :unit, :min, :max, :step, :default, :position]

  postgres do
    table "product_options"
    repo Mercator.Repo

    references do
      reference :product, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:product_id, :key, :kind | @editable]
    end

    update :update do
      primary? true
      accept @editable
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

    attribute :key, :string do
      description ~s(Stable key used in configurations, e.g. "species" or "length".)
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9_]+$/, max_length: 50
    end

    attribute :name, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 100
    end

    attribute :kind, Mercator.Catalog.OptionKind, allow_nil?: false, public?: true
    attribute :role, Mercator.Catalog.OptionRole, allow_nil?: false, default: :info, public?: true

    attribute :unit, :string do
      description "Unit of number options, e.g. \"mm\"."
      public? true
      constraints max_length: 20
    end

    attribute :min, :decimal, public?: true
    attribute :max, :decimal, public?: true
    attribute :step, :decimal, public?: true
    attribute :default, :decimal, public?: true
    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    timestamps()
  end

  relationships do
    belongs_to :product, Mercator.Catalog.Product, allow_nil?: false, public?: true

    has_many :choices, Mercator.Catalog.OptionChoice do
      destination_attribute :option_id
      sort position: :asc, key: :asc
      public? true
    end
  end

  identities do
    identity :unique_product_key, [:product_id, :key]
  end
end
