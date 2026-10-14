defmodule Mercator.Content.Blocks.Column do
  @moduledoc "One column of a Columns block: title and Markdown text."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :title, Mercator.Translated, public?: true
    attribute :text, Mercator.Translated, public?: true
  end
end
