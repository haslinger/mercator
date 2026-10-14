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
        text: [type: Mercator.Content.Blocks.Text, tag: :type, tag_value: "text"],
        hero: [type: Mercator.Content.Blocks.Hero, tag: :type, tag_value: "hero"],
        text_image: [type: Mercator.Content.Blocks.TextImage, tag: :type, tag_value: "text_image"],
        image: [type: Mercator.Content.Blocks.Image, tag: :type, tag_value: "image"],
        gallery: [type: Mercator.Content.Blocks.Gallery, tag: :type, tag_value: "gallery"],
        download: [type: Mercator.Content.Blocks.Download, tag: :type, tag_value: "download"],
        products: [type: Mercator.Content.Blocks.Products, tag: :type, tag_value: "products"],
        categories: [
          type: Mercator.Content.Blocks.Categories,
          tag: :type,
          tag_value: "categories"
        ],
        columns: [type: Mercator.Content.Blocks.Columns, tag: :type, tag_value: "columns"],
        faq: [type: Mercator.Content.Blocks.Faq, tag: :type, tag_value: "faq"],
        shared: [type: Mercator.Content.Blocks.Shared, tag: :type, tag_value: "shared"],
        call_to_action: [
          type: Mercator.Content.Blocks.CallToAction,
          tag: :type,
          tag_value: "call_to_action"
        ]
      ]
    ]
end
