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

  use Gettext, backend: MercatorWeb.Gettext

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
    :shipping,
    :pricing,
    :min_billing_quantity,
    :min_order_value,
    :rounding_mm,
    :cutting_fee
  ]

  postgres do
    table "products"
    repo Mercator.Repo

    references do
      reference :tax_class, on_delete: :restrict
    end

    # Full-text search (#56): one weighted document per language (title A,
    # subtitle + description B) and a GIN index on the same expression.
    custom_statements do
      statement :product_search_document do
        up """
        CREATE OR REPLACE FUNCTION mercator_product_document(lang regconfig, locale text, title jsonb, subtitle jsonb, description jsonb)
        RETURNS tsvector LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
          SELECT setweight(to_tsvector(lang, coalesce(title->>locale, '')), 'A') ||
                 setweight(to_tsvector(lang, coalesce(subtitle->>locale, '') || ' ' || coalesce(description->>locale, '')), 'B')
        $$;
        """

        down "DROP FUNCTION IF EXISTS mercator_product_document(regconfig, text, jsonb, jsonb, jsonb);"
      end

      statement :products_search_de_index do
        up "CREATE INDEX products_search_de_index ON products USING gin (mercator_product_document('german', 'de', title, subtitle, description));"
        down "DROP INDEX IF EXISTS products_search_de_index;"
      end

      statement :products_search_en_index do
        up "CREATE INDEX products_search_en_index ON products USING gin (mercator_product_document('english', 'en', title, subtitle, description));"
        down "DROP INDEX IF EXISTS products_search_en_index;"
      end
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

    read :search do
      description "Full-text search over titles, subtitles and descriptions (de and en) and article numbers."
      # an empty query (nil) finds nothing instead of failing
      argument :query, :string, allow_nil?: true
      prepare Mercator.Catalog.Preparations.Search
    end

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

  validations do
    validate present(:pricing),
      where: [attribute_equals(:kind, :configurable)],
      message: dgettext_noop("errors", "configurable products need a pricing model")
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

    # --- configurable products (#55) ---

    attribute :pricing, Mercator.Catalog.PricingModel do
      description "Price calculation of configurable products."
      public? true
    end

    attribute :min_billing_quantity, :decimal do
      description "Minimum measure billed per order line, in the pricing unit (e.g. 0.1 m³)."
      public? true
      constraints min: 0
    end

    attribute :min_order_value, :decimal do
      description "Minimum net value of an order line."
      public? true
      constraints min: 0
    end

    attribute :rounding_mm, :integer do
      description "Dimensions are rounded up to multiples of this, e.g. 10 for whole cm."
      public? true
      constraints min: 1
    end

    attribute :cutting_fee, :decimal do
      description "Net fee per piece for cutting to size."
      public? true
      constraints min: 0
    end

    timestamps()
  end

  relationships do
    belongs_to :tax_class, Mercator.Catalog.TaxClass do
      allow_nil? false
      public? true
    end

    # number as tie-breaker, so equal positions still give a stable order
    has_many :variants, Mercator.Catalog.Variant do
      sort position: :asc, number: :asc
      public? true
    end

    has_many :categorizations, Mercator.Catalog.Categorization, public?: true

    many_to_many :categories, Mercator.Catalog.Category do
      through Mercator.Catalog.Categorization
      public? true
    end

    has_many :product_properties, Mercator.Catalog.ProductProperty, public?: true

    has_many :images, Mercator.Catalog.Image do
      sort position: :asc, inserted_at: :asc
      public? true
    end

    has_many :options, Mercator.Catalog.ProductOption do
      sort position: :asc, key: :asc
      public? true
    end

    has_many :relations, Mercator.Catalog.ProductRelation do
      sort position: :asc, inserted_at: :asc
      public? true
    end
  end

  identities do
    identity :unique_number, [:number]
    identity :unique_slug, [:slug]
  end
end
