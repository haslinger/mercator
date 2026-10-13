defmodule Mercator.Catalog.Product do
  @moduledoc """
  A product. Every product has at least one variant (the sellable item with
  number, stock and prices); a simple product has exactly one.

  States (#52): `draft` → `active` → `discontinued`. Only active products are
  visible to customers.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Catalog.Changes.SetSlug
  alias Mercator.Catalog.Validations.HasVariant

  @editable [
    :number,
    :title,
    :subtitle,
    :description,
    :long_description,
    :warranty,
    :highlights,
    :slug,
    :kind,
    :tax_class_id,
    :new_arrival,
    :bestseller,
    :shipping
  ]

  postgres do
    table "products"
    repo Mercator.Repo

    references do
      reference :tax_class, on_delete: :restrict
    end
  end

  state_machine do
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :activate, from: [:draft, :discontinued], to: :active
      transition :discontinue, from: [:draft, :active], to: :discontinued
    end
  end

  actions do
    defaults [:read, :destroy]

    read :in_categories do
      description "Products assigned to any of the given categories, by position."
      argument :category_ids, {:array, :uuid}, allow_nil?: false
      filter expr(exists(categorizations, category_id in ^arg(:category_ids)))
      prepare build(sort: [number: :asc])
    end

    create :create do
      primary? true
      accept @editable
      change {SetSlug, from: :title}
    end

    update :update do
      primary? true
      require_atomic? false
      accept @editable
      change {SetSlug, from: :title}
    end

    update :activate do
      description "Make the product visible; it needs at least one variant."
      require_atomic? false
      validate HasVariant
      change transition_state(:active)
    end

    update :discontinue do
      change transition_state(:discontinued)
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
      authorize_if expr(state == :active)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :string do
      description "Article number, e.g. BH-KVH-001."
      allow_nil? false
      public? true
      constraints match: ~r/^[A-Z0-9][A-Z0-9._-]*$/, max_length: 50
    end

    attribute :title, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 200
    end

    attribute :subtitle, Mercator.Translated do
      public? true
      constraints max_length: 300
    end

    attribute :description, Mercator.Translated do
      public? true
      constraints max_length: 2000
    end

    attribute :long_description, Mercator.Translated, public?: true
    attribute :warranty, Mercator.Translated, public?: true

    attribute :highlights, {:array, Mercator.Translated} do
      description "Bullet points shown on the product page (Rails: features)."
      allow_nil? false
      default []
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9]+(-[a-z0-9]+)*$/, max_length: 200
    end

    attribute :kind, Mercator.Catalog.ProductKind do
      allow_nil? false
      default :simple
      public? true
    end

    attribute :new_arrival, :boolean do
      description "Shown with a \"new\" badge (#53)."
      allow_nil? false
      default false
      public? true
    end

    attribute :bestseller, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :shipping, Mercator.Catalog.Shipping do
      allow_nil? false
      default :parcel
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :tax_class, Mercator.Catalog.TaxClass do
      allow_nil? false
      public? true
    end

    has_many :variants, Mercator.Catalog.Variant do
      sort position: :asc
      public? true
    end

    has_many :categorizations, Mercator.Catalog.Categorization, public?: true

    many_to_many :categories, Mercator.Catalog.Category do
      through Mercator.Catalog.Categorization
      public? true
    end

    has_many :product_properties, Mercator.Catalog.ProductProperty, public?: true

    has_many :relations, Mercator.Catalog.ProductRelation do
      sort position: :asc
      public? true
    end
  end

  identities do
    identity :unique_number, [:number]
    identity :unique_slug, [:slug]
  end
end
