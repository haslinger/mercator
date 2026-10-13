defmodule Mercator.Catalog do
  @moduledoc """
  Catalogue domain: categories, products, variants, prices, units, tax
  classes, properties and configurable products. See docs/catalog-design.md.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshAdmin.Domain, AshPhoenix]

  defdelegate price_for(variant, quantity \\ 1, date \\ Date.utc_today()),
    to: Mercator.Catalog.Pricing

  defdelegate from_price(product, date \\ Date.utc_today()), to: Mercator.Catalog.Pricing

  defdelegate quote(product, selections, quantity \\ 1), to: Mercator.Catalog.Configurator

  admin do
    show? true
  end

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

    resource Mercator.Catalog.Product do
      define :list_products, action: :read
      define :list_products_in_categories, action: :in_categories, args: [:category_ids]
      define :search_products, action: :search, args: [:query]
      define :get_product, action: :read, get_by: [:id]
      define :get_product_by_slug, action: :read, get_by: [:slug]
      define :get_product_by_number, action: :read, get_by: [:number]
      define :create_product, action: :create
      define :update_product, action: :update
      define :activate_product, action: :activate
      define :discontinue_product, action: :discontinue
      define :destroy_product, action: :destroy
    end

    resource Mercator.Catalog.Variant do
      define :get_variant, action: :read, get_by: [:id]
      define :get_variant_by_number, action: :read, get_by: [:number]
      define :create_variant, action: :create
      define :update_variant, action: :update
      define :destroy_variant, action: :destroy
    end

    resource Mercator.Catalog.Price do
      define :create_price, action: :create
      define :update_price, action: :update
      define :destroy_price, action: :destroy
    end

    resource Mercator.Catalog.Categorization do
      define :categorize, action: :create, args: [:category_id, :product_id]
      define :destroy_categorization, action: :destroy
    end

    resource Mercator.Catalog.ProductOption do
      define :create_product_option, action: :create
      define :update_product_option, action: :update
    end

    resource Mercator.Catalog.OptionChoice do
      define :create_option_choice, action: :create
      define :update_option_choice, action: :update
    end

    resource Mercator.Catalog.Image do
      define :upload_image, action: :upload
      define :update_image, action: :update
      define :destroy_image, action: :destroy
    end

    resource Mercator.Catalog.PropertyGroup do
      define :list_property_groups, action: :read
      define :create_property_group, action: :create
    end

    resource Mercator.Catalog.Property do
      define :list_properties, action: :read
      define :create_property, action: :create
      define :update_property, action: :update
    end

    resource Mercator.Catalog.ProductProperty do
      define :set_product_property, action: :create
      define :update_product_property, action: :update
    end

    resource Mercator.Catalog.ProductRelation do
      define :relate_products, action: :create
      define :destroy_product_relation, action: :destroy
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
