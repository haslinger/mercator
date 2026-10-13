defmodule Mercator.Sales.BasketPricing do
  @moduledoc """
  Live prices of a basket: each item is priced with the current prices
  (graduated, promotions) or, for configurable products, the configurator.
  Items whose product is no longer available are marked and not counted.
  """

  alias Mercator.Catalog

  @doc """
  Returns `%{lines: [line], net:, vat_by_rate: [{rate, vat}], vat:, gross:}`.
  Each line: `%{item, variant, product, available?, unit_net, net, vat, gross, vat_rate}`.
  """
  def calculate(nil), do: calculate(%{items: []})

  def calculate(%{items: items}) do
    lines = Enum.map(items, &line/1)
    priced = Enum.filter(lines, & &1.available?)

    vat_by_rate =
      priced
      |> Enum.group_by(& &1.vat_rate)
      |> Enum.map(fn {rate, group} -> {rate, sum(group, :vat)} end)
      |> Enum.sort_by(fn {rate, _} -> rate end, {:desc, Decimal})

    net = sum(priced, :net)
    vat = sum(priced, :vat)

    %{lines: lines, net: net, vat_by_rate: vat_by_rate, vat: vat, gross: Decimal.add(net, vat)}
  end

  defp line(item) do
    variant = item.variant
    product = variant.product
    base = %{item: item, variant: variant, product: product}

    case price(product, variant, item) do
      {:ok, %{net: net, vat: vat, gross: gross, vat_rate: rate, unit_net: unit_net}}
      when variant.active and product.state == :active ->
        Map.merge(base, %{
          available?: true,
          unit_net: unit_net,
          net: net,
          vat: vat,
          gross: gross,
          vat_rate: rate
        })

      _ ->
        Map.merge(base, %{
          available?: false,
          unit_net: nil,
          net: nil,
          vat: nil,
          gross: nil,
          vat_rate: nil
        })
    end
  end

  defp price(%{kind: :configurable} = product, _variant, item) do
    case Catalog.quote(product, item.selections, Decimal.to_integer(item.quantity)) do
      {:ok, quote} -> {:ok, Map.take(quote, [:net, :vat, :gross, :vat_rate, :unit_net])}
      error -> error
    end
  end

  defp price(product, variant, item) do
    case Catalog.price_for(%{variant | product: product}, item.quantity) do
      {:ok, info} ->
        {:ok,
         %{
           net: info.net,
           vat: info.vat,
           gross: info.gross,
           vat_rate: info.vat_rate,
           unit_net: info.unit_net
         }}

      error ->
        error
    end
  end

  defp sum(lines, key),
    do: lines |> Enum.map(&Map.fetch!(&1, key)) |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
end
