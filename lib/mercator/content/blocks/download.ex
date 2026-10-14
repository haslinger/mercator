defmodule Mercator.Content.Blocks.Download do
  @moduledoc "Block: a PDF from the media library to download."
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :document_id, :uuid, public?: true
    attribute :label, Mercator.Translated, public?: true
  end
end
