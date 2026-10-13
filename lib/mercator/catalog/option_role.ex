defmodule Mercator.Catalog.OptionRole do
  @moduledoc """
  The role of a configurator option in the price calculation:

    * `:base_price` – choice option whose choices carry the base price (one per product)
    * `:surcharge` – choice option whose choices add absolute or percent surcharges
    * `:length`, `:width`, `:thickness` – number options (in mm) for the measure
    * `:info` – no influence on the price
  """
  use Ash.Type.Enum, values: [:base_price, :surcharge, :length, :width, :thickness, :info]
end
