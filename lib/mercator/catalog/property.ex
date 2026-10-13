defmodule Mercator.Catalog.Property do
  @moduledoc """
  A product property, e.g. "Holzart" (text), "Stärke" (number in mm) or
  "imprägniert" (yes/no). Filterable properties become filters on category
  pages.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  @editable [:name, :kind, :unit, :filterable, :position, :property_group_id]

  postgres do
    table "properties"
    repo Mercator.Repo

    references do
      reference :property_group, on_delete: :restrict
    end
  end

  actions do
    defaults [:read, :destroy, create: @editable, update: @editable -- [:kind]]
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

    attribute :kind, Mercator.Catalog.PropertyKind,
      allow_nil?: false,
      default: :text,
      public?: true

    attribute :unit, :string do
      description ~s(Unit symbol for numbers, e.g. "mm" or "kg/m³".)
      public? true
      constraints max_length: 20
    end

    attribute :filterable, :boolean, allow_nil?: false, default: true, public?: true
    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    timestamps()
  end

  relationships do
    belongs_to :property_group, Mercator.Catalog.PropertyGroup do
      allow_nil? false
      public? true
    end
  end
end
