defmodule Mercator.Catalog.Shipping do
  @moduledoc """
  How a product is delivered: `:parcel`, `:freight` (houses, full pallets),
  `:pickup_only` or `:none` (services). Replaces Rails' `not_shippable`.
  """
  use Ash.Type.Enum, values: [:parcel, :freight, :pickup_only, :none]
end
