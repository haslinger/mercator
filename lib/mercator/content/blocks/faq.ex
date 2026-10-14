defmodule Mercator.Content.Blocks.Faq do
  @moduledoc "Block: questions and answers, shown as an accordion."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :heading, Mercator.Translated, public?: true
    attribute :items, {:array, Mercator.Content.Blocks.FaqItem}, public?: true, default: []
  end
end
