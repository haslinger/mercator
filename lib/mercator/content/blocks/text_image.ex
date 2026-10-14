defmodule Mercator.Content.Blocks.TextImage do
  @moduledoc "Block: a Markdown text next to an image, the image left or right."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :text, Mercator.Translated, public?: true
    attribute :image_id, :uuid, public?: true

    attribute :image_side, :atom do
      public? true
      default :right
      constraints one_of: [:left, :right]
    end
  end
end
