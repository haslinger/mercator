defmodule MercatorWeb.Format do
  @moduledoc """
  Locale-aware formatting of money, quantities and units for templates.
  """
  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Catalog.Unit

  @doc """
  Formats an amount in euros, e.g. `"1.234,50 €"` (de) or `"€1,234.50"` (en).

      iex> MercatorWeb.Format.money(Decimal.new("1234.5"), "de")
      "1.234,50 €"
      iex> MercatorWeb.Format.money(Decimal.new("1234.5"), "en")
      "€1,234.50"
  """
  def money(nil, _locale), do: nil

  def money(%Decimal{} = amount, locale) do
    formatted = amount |> Decimal.round(2) |> number(2, locale)

    case to_string(locale) do
      "en" -> "€" <> formatted
      _ -> formatted <> " €"
    end
  end

  @doc """
  Formats a quantity: no decimals for countable units, up to 3 otherwise.

      iex> MercatorWeb.Format.quantity(Decimal.new("2.50"), :m3, "de")
      "2,5"
      iex> MercatorWeb.Format.quantity(Decimal.new(3), :piece, "en")
      "3"
  """
  def quantity(%Decimal{} = quantity, unit, locale) do
    decimals = if Unit.decimals?(unit), do: 3, else: 0

    quantity
    |> Decimal.round(decimals)
    |> Decimal.normalize()
    |> then(&number(&1, places(&1), locale))
  end

  @doc ~s(Price per unit, e.g. "pro m³" / "per m³".)
  def per_unit(unit), do: gettext("per %{unit}", unit: Unit.symbol(unit))

  defp places(%Decimal{exp: exp}) when exp < 0, do: -exp
  defp places(_decimal), do: 0

  defp number(decimal, places, locale) do
    {thousands, comma} = if to_string(locale) == "en", do: {",", "."}, else: {".", ","}
    [int, frac] = decimal |> Decimal.to_string(:normal) |> pad(places) |> String.split(".")

    int =
      int
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(thousands, &Enum.join/1)
      |> String.reverse()

    if places == 0, do: int, else: int <> comma <> frac
  end

  defp pad(string, places) do
    case String.split(string, ".") do
      [int] -> int <> "." <> String.duplicate("0", places)
      [int, frac] -> int <> "." <> String.pad_trailing(frac, places, "0")
    end
  end
end
