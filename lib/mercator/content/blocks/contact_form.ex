defmodule Mercator.Content.Blocks.ContactForm do
  @moduledoc "Block: the contact form (#83) with an introduction."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :intro, Mercator.Translated, public?: true
  end
end
