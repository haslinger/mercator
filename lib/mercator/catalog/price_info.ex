defmodule Mercator.Catalog.PriceInfo do
  @moduledoc """
  The result of a price determination for a variant and quantity.

  Unit prices keep 4 decimals; totals are rounded to cents. The VAT is
  calculated on the rounded net total, so `net + vat == gross` always holds.
  `regular_unit_net`/`regular_unit_gross` are set when a promotion price
  applies, for showing the regular price crossed out.
  """
  @enforce_keys [:quantity, :unit_net, :unit_gross, :vat_rate, :net, :vat, :gross]
  defstruct [
    :quantity,
    :unit_net,
    :unit_gross,
    :vat_rate,
    :net,
    :vat,
    :gross,
    :regular_unit_net,
    :regular_unit_gross,
    promotion?: false
  ]

  @type t :: %__MODULE__{}
end
