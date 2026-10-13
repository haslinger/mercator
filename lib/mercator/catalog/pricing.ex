defmodule Mercator.Catalog.Pricing do
  @moduledoc """
  Price determination for variants (catalog-design.md, section 3 "Price").

  Rules for choosing among a variant's price rows:

    * a row applies when it is valid on the date (`valid_from`/`valid_until`,
      both optional) and its `min_quantity` is at most the ordered quantity
    * graduated prices: among applicable rows the highest `min_quantity` wins,
      ties go to the lower amount
    * a promotion row wins over the regular row only if it is cheaper; the
      regular price is then reported for display (crossed out)

  Prices are net (#50); VAT comes from the product's tax class.
  """

  alias Mercator.Catalog.{Configurator, PriceInfo, Variant}

  @doc """
  The price of `quantity` units of a variant on `date`.

  Loads the variant's prices and its product's tax class if needed.
  Returns `{:ok, %PriceInfo{}}` or `{:error, :no_price}`.
  """
  def price_for(%Variant{} = variant, quantity \\ 1, date \\ Date.utc_today()) do
    variant = Ash.load!(variant, [:prices, product: :tax_class], authorize?: false, lazy?: true)
    quantity = Decimal.new(quantity)

    case select(variant.prices, quantity, date) do
      {nil, _regular} -> {:error, :no_price}
      {price, regular} -> {:ok, build(price, regular, quantity, variant.product.tax_class.rate)}
    end
  end

  @doc """
  The lowest unit price of a product's active variants for a single unit:
  the "from" price on category pages. Returns `{:ok, %PriceInfo{}}` or
  `{:error, :no_price}`.
  """
  def from_price(product, date \\ Date.utc_today())

  # configurable products: the price of one piece in the default configuration
  def from_price(%{kind: :configurable} = product, _date) do
    case Configurator.quote(product, %{}, 1) do
      {:ok, quote} ->
        {:ok,
         %PriceInfo{
           quantity: Decimal.new(1),
           unit_net: quote.net,
           unit_gross: quote.gross,
           vat_rate: quote.vat_rate,
           net: quote.net,
           vat: quote.vat,
           gross: quote.gross
         }}

      {:error, _} ->
        {:error, :no_price}
    end
  end

  def from_price(product, date) do
    product = Ash.load!(product, [:tax_class, variants: :prices], authorize?: false, lazy?: true)

    product.variants
    |> Enum.filter(& &1.active)
    |> Enum.map(&price_for(%{&1 | product: product}, 1, date))
    |> Enum.flat_map(fn
      {:ok, info} -> [info]
      {:error, _} -> []
    end)
    |> Enum.min_by(& &1.unit_net, Decimal, fn -> nil end)
    |> case do
      nil -> {:error, :no_price}
      info -> {:ok, info}
    end
  end

  @doc """
  Chooses the effective price row and the regular row it replaces (if it is
  a promotion). Returns `{effective, regular_or_nil}`; `effective` is nil if
  no row applies.
  """
  def select(prices, quantity, date) do
    applicable = Enum.filter(prices, &applies?(&1, quantity, date))
    regular = best(Enum.reject(applicable, & &1.promotion))
    promotion = best(Enum.filter(applicable, & &1.promotion))

    if promotion && (is_nil(regular) || Decimal.lt?(promotion.amount, regular.amount)) do
      {promotion, regular}
    else
      {regular, nil}
    end
  end

  defp applies?(price, quantity, date) do
    Decimal.compare(price.min_quantity, quantity) != :gt and
      (is_nil(price.valid_from) or Date.compare(price.valid_from, date) != :gt) and
      (is_nil(price.valid_until) or Date.compare(price.valid_until, date) != :lt)
  end

  # highest min_quantity, then lowest amount
  defp best([]), do: nil

  defp best(prices) do
    Enum.min_by(prices, &{Decimal.negate(&1.min_quantity), &1.amount}, fn {qa, aa}, {qb, ab} ->
      case Decimal.compare(qa, qb) do
        :lt -> true
        :gt -> false
        :eq -> Decimal.compare(aa, ab) != :gt
      end
    end)
  end

  defp build(price, regular, quantity, rate) do
    net = price.amount |> Decimal.mult(quantity) |> Decimal.round(2)
    vat = net |> Decimal.mult(rate) |> Decimal.div(100) |> Decimal.round(2)

    %PriceInfo{
      quantity: quantity,
      unit_net: price.amount,
      unit_gross: gross(price.amount, rate),
      vat_rate: rate,
      net: net,
      vat: vat,
      gross: Decimal.add(net, vat),
      promotion?: regular != nil,
      regular_unit_net: regular && regular.amount,
      regular_unit_gross: regular && gross(regular.amount, rate)
    }
  end

  defp gross(net, rate) do
    net |> Decimal.mult(Decimal.add(100, rate)) |> Decimal.div(100) |> Decimal.round(2)
  end
end
