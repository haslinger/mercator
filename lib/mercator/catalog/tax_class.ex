defmodule Mercator.Catalog.TaxClass do
  @moduledoc """
  A VAT rate products are taxed with, e.g. "Normalsatz 20 %" or
  "ermäßigt 13 %" (decision #51). Prices are stored net (#50).
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "tax_classes"
    repo Mercator.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:key, :name, :rate, :position]
    end

    update :update do
      primary? true
      accept [:name, :rate, :position]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {ActorHasRole, role: :administrator}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :key, :string do
      description "Stable identifier used in seeds and code, e.g. \"standard\"."
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9_]+$/, max_length: 50
    end

    attribute :name, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 100
    end

    attribute :rate, :decimal do
      description "VAT rate in percent, e.g. 20 or 13."
      allow_nil? false
      public? true
      constraints min: 0, max: 100
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :products, Mercator.Catalog.Product, public?: true
  end

  aggregates do
    count :product_count, :products, public?: true
  end

  identities do
    identity :unique_key, [:key]
  end
end
