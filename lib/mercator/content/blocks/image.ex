defmodule Mercator.Content.Blocks.Image do
  @moduledoc "Block: one image with a caption."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :image_id, :uuid, public?: true
    attribute :caption, Mercator.Translated, public?: true
  end
end
