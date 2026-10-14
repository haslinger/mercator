defmodule Mercator.Consulting.OfferItem do
  @moduledoc """
  An offer item: a product variant (with its configuration for configurable
  products) or a free-text item such as "Fundament, Montage".

  Texts are taken over in the offer's language. `list_unit_net` is the
  price list's unit price when the item was added; `unit_net` may be set
  lower or higher by the consultant. Items change only while the offer is
  a draft.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Consulting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Consulting.Validations.OfferEditable

  postgres do
    table "offer_items"
    repo Mercator.Repo

    references do
      reference :offer, on_delete: :delete
      reference :variant, on_delete: :nilify
      reference :product, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :offer_id,
        :position,
        :kind,
        :number,
        :title,
        :description,
        :selections,
        :quantity,
        :unit,
        :list_unit_net,
        :unit_net,
        :discount_percent,
        :vat_rate,
        :delivery_time,
        :variant_id,
        :product_id
      ]

      validate OfferEditable
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :position,
        :title,
        :description,
        :quantity,
        :unit,
        :list_unit_net,
        :unit_net,
        :discount_percent,
        :vat_rate,
        :delivery_time
      ]

      validate OfferEditable
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      validate OfferEditable
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(
                     offer.customer_id == ^actor(:id) and
                       offer.state in [:sent, :accepted, :expired]
                   )

      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :position, :integer, allow_nil?: false, public?: true

    attribute :kind, :atom do
      allow_nil? false
      default :product
      public? true
      constraints one_of: [:product, :text]
    end

    attribute :number, :string do
      description "Article number, or the configuration number of a configured product."
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 500, trim?: true
    end

    attribute :description, :string do
      description "Variant, configuration or any details."
      public? true
      constraints max_length: 4000
    end

    attribute :selections, :map do
      description "Configuration of a configurable product (option key => value)."
      allow_nil? false
      default %{}
      public? true
    end

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      constraints greater_than: 0
    end

    attribute :unit, Mercator.Catalog.Unit, allow_nil?: false, default: :piece, public?: true
    attribute :list_unit_net, :decimal, public?: true

    attribute :unit_net, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :discount_percent, :decimal do
      allow_nil? false
      default Decimal.new(0)
      public? true
      constraints min: 0, max: 100
    end

    attribute :vat_rate, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :delivery_time, :string, public?: true, constraints: [max_length: 200]
    timestamps()
  end

  relationships do
    belongs_to :offer, Mercator.Consulting.Offer, allow_nil?: false, public?: true
    belongs_to :variant, Mercator.Catalog.Variant, public?: true
    belongs_to :product, Mercator.Catalog.Product, public?: true
  end
end
