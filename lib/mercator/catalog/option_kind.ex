defmodule Mercator.Catalog.OptionKind do
  @moduledoc "A configurator option is a choice (e.g. wood species) or a number (e.g. length in mm)."
  use Ash.Type.Enum, values: [:choice, :number]
end
