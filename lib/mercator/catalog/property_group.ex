defmodule Mercator.Catalog.PropertyGroup do
  @moduledoc ~s(Groups properties on the product page, e.g. "Abmessungen" or "Holz".)
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "property_groups"
    repo Mercator.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:name, :position], update: [:name, :position]]
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {ActorHasRole, role: :productmanager}
      authorize_if {ActorHasRole, role: :administrator}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 100
    end

    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    timestamps()
  end

  relationships do
    has_many :properties, Mercator.Catalog.Property do
      sort position: :asc
      public? true
    end
  end
end
