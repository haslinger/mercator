defmodule Mercator.Content.Blocks.Text do
  @moduledoc "Block: a Markdown text (docs/cms-design.md, section 3)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true

    attribute :text, Mercator.Translated do
      public? true
    end
  end
end
