defmodule Mercator.Catalog do
  @moduledoc """
  Catalogue domain: categories, products, variants, prices, units, tax
  classes, properties and configurable products. See docs/catalog-design.md.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshPhoenix]

  resources do
    resource Mercator.Catalog.TaxClass do
      define :list_tax_classes, action: :read
      define :get_tax_class, action: :read, get_by: [:id]
      define :get_tax_class_by_key, action: :read, get_by: [:key]
      define :create_tax_class, action: :create
      define :update_tax_class, action: :update
    end
  end
end
