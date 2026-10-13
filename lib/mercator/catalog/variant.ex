defmodule Mercator.Catalog.Variant do
  @moduledoc """
  The sellable item of a product (Rails: Inventory): own number, options,
  sales unit, stock and prices. Visible when its product is visible.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  @editable [
    :number,
    :name,
    :options,
    :unit,
    :stock,
    :delivery_time,
    :weight_kg,
    :position,
    :active
  ]

  postgres do
    table "variants"
    repo Mercator.Repo

    references do
      reference :product, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept @editable ++ [:product_id]
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
      authorize_if expr(active and product.state == :active)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :string do
      description "Stock keeping number, e.g. BH-TD-LAE-28-145-4000."
      allow_nil? false
      public? true
      constraints match: ~r/^[A-Z0-9][A-Z0-9._-]*$/, max_length: 80
    end

    attribute :name, Mercator.Translated do
      description "Distinguishes the variant, e.g. \"Lärche, 28 × 145 mm, 4 m\"."
      public? true
      constraints max_length: 200
    end

    attribute :options, :map do
      description ~s(Option values for the variant selector, e.g. %{"species" => "larch"}.)
      allow_nil? false
      default %{}
      public? true
    end

    attribute :unit, Mercator.Catalog.Unit do
      allow_nil? false
      default :piece
      public? true
    end

    attribute :stock, :decimal do
      description "Quantity in stock; nil = made to order or not tracked (#54)."
      public? true
      constraints min: 0
    end

    attribute :delivery_time, Mercator.Translated do
      public? true
      constraints max_length: 100
    end

    attribute :weight_kg, :decimal do
      public? true
      constraints min: 0
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :active, :boolean do
      allow_nil? false
      default true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Mercator.Catalog.Product do
      allow_nil? false
      public? true
    end

    has_many :prices, Mercator.Catalog.Price do
      sort min_quantity: :asc
      public? true
    end
  end

  identities do
    identity :unique_number, [:number]
  end
end
