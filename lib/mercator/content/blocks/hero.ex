defmodule Mercator.Content.Blocks.Hero do
  @moduledoc "Block: a large image with headline, text and a button (docs/cms-design.md, section 3)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :image_id, :uuid, public?: true
    attribute :headline, Mercator.Translated, public?: true
    attribute :text, Mercator.Translated, public?: true
    attribute :button_label, Mercator.Translated, public?: true
    attribute :button_link, :string, public?: true, constraints: [max_length: 500]
  end
end
