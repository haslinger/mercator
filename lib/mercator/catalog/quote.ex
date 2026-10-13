defmodule Mercator.Catalog.Quote do
  @moduledoc """
  The calculated price of one configuration of a configurable product (#55).

    * `selections` – normalised configuration, option key => value string
      (choice key, or the rounded number)
    * `measure` – measure of one piece in `measure_unit` (m³, m², lfm, piece)
    * `billed_measure` – total measure billed (at least the minimum billing quantity)
    * `lines` – breakdown, each `%{type, name, amount}` with type `:base`,
      `:surcharge`, `:cutting_fee` or `:minimum`
    * `net`, `vat`, `gross` – totals for all pieces, rounded to cents
    * `config_number` – article number of this configuration
  """
  @enforce_keys [:quantity, :selections, :lines, :net, :vat, :gross, :vat_rate, :config_number]
  defstruct [
    :quantity,
    :selections,
    :measure,
    :measure_unit,
    :billed_measure,
    :base_price,
    :lines,
    :net,
    :vat,
    :gross,
    :vat_rate,
    :unit_net,
    :config_number
  ]

  @type t :: %__MODULE__{}
end
