defmodule Mercator.Content.Blocks.Categories do
  @moduledoc "Block: categories as tiles; without a choice the top-level categories."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :heading, Mercator.Translated, public?: true
    attribute :category_ids, {:array, :uuid}, public?: true, default: []
  end
end
