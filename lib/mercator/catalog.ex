defmodule Mercator.Catalog do
  @moduledoc """
  Catalogue domain: categories, products, variants, prices, units, tax
  classes, properties and configurable products. See docs/catalog-design.md.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshPhoenix]

  resources do
    resource Mercator.Catalog.Category do
      define :list_categories, action: :read
      define :list_root_categories, action: :roots
      define :list_child_categories, action: :children, args: [:category_id]
      define :list_category_ancestors, action: :ancestors, args: [:category_id]
      define :list_category_subtree, action: :subtree, args: [:category_id]
      define :get_category, action: :read, get_by: [:id]
      define :get_category_by_slug, action: :read, get_by: [:slug]
      define :create_category, action: :create
      define :update_category, action: :update
      define :move_category, action: :move, args: [:parent_id]
      define :activate_category, action: :activate
      define :hide_category, action: :hide
      define :deactivate_category, action: :deactivate
      define :destroy_category, action: :destroy
    end

    resource Mercator.Catalog.TaxClass do
      define :list_tax_classes, action: :read
      define :get_tax_class, action: :read, get_by: [:id]
      define :get_tax_class_by_key, action: :read, get_by: [:key]
      define :create_tax_class, action: :create
      define :update_tax_class, action: :update
    end
  end
end
