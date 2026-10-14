defmodule Mercator.Content.Block do
  @moduledoc """
  One block of a page (#76): a union of the block types, stored as a map
  with a `"type"` key. New block types are added here and in
  `MercatorWeb.ContentComponents.block/1`.
  """
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      storage: :map_with_tag,
      types: [
        text: [type: Mercator.Content.Blocks.Text, tag: :type, tag_value: "text"]
      ]
    ]
end
