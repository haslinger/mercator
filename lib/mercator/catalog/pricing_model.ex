defmodule Mercator.Catalog.PricingModel do
  @moduledoc """
  How the price of a configurable product is calculated (#55):

    * `:per_volume` – base price per m³ × length × width × thickness
    * `:per_area` – base price per m² × length × width
    * `:per_length` – base price per running metre × length
    * `:per_unit` – base price per piece
  """
  use Ash.Type.Enum, values: [:per_volume, :per_area, :per_length, :per_unit]
end
