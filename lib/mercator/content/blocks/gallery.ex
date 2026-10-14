defmodule Mercator.Content.Blocks.Gallery do
  @moduledoc "Block: several images as a grid."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :image_ids, {:array, :uuid}, public?: true, default: []
  end
end
