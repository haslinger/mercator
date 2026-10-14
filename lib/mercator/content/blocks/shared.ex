defmodule Mercator.Content.Blocks.Shared do
  @moduledoc """
  Block: the published blocks of a shared page (kind `shared`), maintained
  once and shown on several pages.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :page_id, :uuid, public?: true
  end
end
