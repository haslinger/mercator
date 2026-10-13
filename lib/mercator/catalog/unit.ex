defmodule Mercator.Catalog.Unit do
  @moduledoc """
  Sales units (decision #40). Quantities in units with `decimals?` may be
  fractional, e.g. 2.5 m³.
  """
  use Ash.Type.Enum,
    values: [:piece, :lfm, :m2, :m3, :fm, :rm, :srm, :kg, :t, :pallet, :sack]

  use Gettext, backend: MercatorWeb.Gettext

  @units %{
    piece: %{symbol: "Stk.", dimension: :count, decimals?: false},
    lfm: %{symbol: "lfm", dimension: :length, decimals?: true},
    m2: %{symbol: "m²", dimension: :area, decimals?: true},
    m3: %{symbol: "m³", dimension: :volume, decimals?: true},
    fm: %{symbol: "fm", dimension: :volume, decimals?: true},
    rm: %{symbol: "rm", dimension: :volume, decimals?: true},
    srm: %{symbol: "srm", dimension: :volume, decimals?: true},
    kg: %{symbol: "kg", dimension: :mass, decimals?: true},
    t: %{symbol: "t", dimension: :mass, decimals?: true},
    pallet: %{symbol: "Pal.", dimension: :count, decimals?: false},
    sack: %{symbol: "Sack", dimension: :count, decimals?: false}
  }

  @doc "The short symbol, e.g. `\"m³\"`."
  def symbol(unit), do: @units[unit].symbol

  @doc "The physical dimension: `:count`, `:length`, `:area`, `:volume` or `:mass`."
  def dimension(unit), do: @units[unit].dimension

  @doc "Whether quantities in this unit may have decimals."
  def decimals?(unit), do: @units[unit].decimals?

  @doc "The translated name of the unit in the current Gettext locale."
  def label(:piece), do: gettext("piece")
  def label(:lfm), do: gettext("running metre")
  def label(:m2), do: gettext("square metre")
  def label(:m3), do: gettext("cubic metre")
  def label(:fm), do: gettext("solid cubic metre (Festmeter)")
  def label(:rm), do: gettext("stacked cubic metre (Raummeter)")
  def label(:srm), do: gettext("loose cubic metre (Schüttraummeter)")
  def label(:kg), do: gettext("kilogram")
  def label(:t), do: gettext("tonne")
  def label(:pallet), do: gettext("pallet")
  def label(:sack), do: gettext("sack")
end
