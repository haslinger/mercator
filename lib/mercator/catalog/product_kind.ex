defmodule Mercator.Catalog.ProductKind do
  @moduledoc """
  Product kinds (decision #39):

    * `:simple` – one variant, one price
    * `:variants` – several variants, each with its own number, stock and price
    * `:configurable` – price calculated from options and dimensions
  """
  use Ash.Type.Enum, values: [:simple, :variants, :configurable]
end
