defmodule Mercator.Content.Blocks.CallToAction do
  @moduledoc "Block: a highlighted box with headline, text and a button."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :headline, Mercator.Translated, public?: true
    attribute :text, Mercator.Translated, public?: true
    attribute :button_label, Mercator.Translated, public?: true
    attribute :button_link, :string, public?: true, constraints: [max_length: 500]
  end
end
