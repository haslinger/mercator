defmodule Mercator.Sales.OrderItem do
  @moduledoc """
  An order line: a snapshot of article number, texts, quantity and prices.
  The references to variant and product only serve as links and become nil
  when those are deleted.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "order_items"
    repo Mercator.Repo

    references do
      reference :order, on_delete: :delete
      reference :variant, on_delete: :nilify
      reference :product, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :position,
        :number,
        :title,
        :variant_name,
        :configuration,
        :unit,
        :quantity,
        :unit_net,
        :vat_rate,
        :net,
        :vat,
        :gross,
        :variant_id,
        :product_id
      ]
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action_type(:create) do
      # only as part of placing an order
      authorize_if accessing_from(Mercator.Sales.Order, :items)
    end

    policy action_type(:read) do
      authorize_if expr(order.user_id == ^actor(:id))
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :position, :integer, allow_nil?: false, public?: true

    attribute :number, :string do
      description "Article number, or the configuration number of a configured product; nil for free-text items of an offer."
      public? true
    end

    attribute :title, Mercator.Translated, allow_nil?: false, public?: true
    attribute :variant_name, Mercator.Translated, public?: true

    attribute :configuration, Mercator.Translated do
      description "The configuration of a configurable product as text."
      public? true
    end

    attribute :unit, Mercator.Catalog.Unit, allow_nil?: false, public?: true
    attribute :quantity, :decimal, allow_nil?: false, public?: true
    attribute :unit_net, :decimal, allow_nil?: false, public?: true
    attribute :vat_rate, :decimal, allow_nil?: false, public?: true
    attribute :net, :decimal, allow_nil?: false, public?: true
    attribute :vat, :decimal, allow_nil?: false, public?: true
    attribute :gross, :decimal, allow_nil?: false, public?: true

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :order, Mercator.Sales.Order, allow_nil?: false, public?: true
    belongs_to :variant, Mercator.Catalog.Variant, public?: true
    belongs_to :product, Mercator.Catalog.Product, public?: true
  end
end
