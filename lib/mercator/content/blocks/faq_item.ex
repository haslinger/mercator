defmodule Mercator.Content.Blocks.FaqItem do
  @moduledoc "One question of an FAQ block, with a Markdown answer."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :question, Mercator.Translated, public?: true
    attribute :answer, Mercator.Translated, public?: true
  end
end
