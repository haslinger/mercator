defmodule Mercator.Catalog.RelationKind do
  @moduledoc """
  Kind of product relation (Rails: Productrelation, Supplyrelation and
  Recommendation): `:related`, `:accessory` or `:recommended`.
  """
  use Ash.Type.Enum, values: [:related, :accessory, :recommended]
end
