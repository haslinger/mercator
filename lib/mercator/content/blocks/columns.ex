defmodule Mercator.Content.Blocks.Columns do
  @moduledoc "Block: two to four columns side by side, e.g. advantages or services."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :items, {:array, Mercator.Content.Blocks.Column}, public?: true, default: []
  end
end
