defmodule Mercator.Content.Blocks.Products do
  @moduledoc """
  Block: products as tiles, from a category (with subcategories), the
  bestsellers, the new arrivals, or a list of article numbers.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :heading, Mercator.Translated, public?: true

    attribute :source, :atom do
      public? true
      default :bestsellers
      constraints one_of: [:bestsellers, :new_arrivals, :category, :numbers]
    end

    attribute :category_id, :uuid, public?: true

    attribute :numbers, :string do
      description "Article numbers (products), separated by commas or spaces."
      public? true
      constraints max_length: 1000
    end

    attribute :limit, :integer, public?: true, default: 4, constraints: [min: 1, max: 24]
  end
end
