defmodule Mercator.Catalog.PropertyKind do
  @moduledoc "Value type of a product property: text, number (with unit) or yes/no."
  use Ash.Type.Enum, values: [:text, :number, :boolean]
end
