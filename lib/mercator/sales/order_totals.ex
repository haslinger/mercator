defmodule Mercator.Sales.OrderTotals do
  @moduledoc """
  Totals of an order: goods from `Mercator.Sales.BasketPricing` plus the
  shipping costs.

  Shipping costs are gross amounts. As an ancillary service they share the
  VAT of the goods: with several VAT rates they are split in proportion to
  the gross value of the goods per rate (common Austrian practice, to be
  confirmed per customer; see #67).
  """

  @doc """
  Returns `%{goods_net, goods_gross, shipping_gross, net, vat, gross,
  vat_lines: [%{rate, net, vat}]}` for the available lines of a pricing.
  """
  def calculate(%{lines: lines}, shipping_gross) do
    goods = lines |> Enum.filter(& &1.available?) |> by_rate()
    goods_gross = sum(goods, :gross)
    shipping = split(goods, goods_gross, shipping_gross)

    vat_lines =
      Enum.map(goods, fn %{rate: rate} = group ->
        %{net: shipping_net, vat: shipping_vat} = Map.fetch!(shipping, rate)

        %{
          rate: rate,
          net: Decimal.add(group.net, shipping_net),
          vat: Decimal.add(group.vat, shipping_vat)
        }
      end)

    net = sum(vat_lines, :net)
    vat = sum(vat_lines, :vat)

    %{
      goods_net: sum(goods, :net),
      goods_gross: goods_gross,
      shipping_gross: shipping_gross,
      net: net,
      vat: vat,
      gross: Decimal.add(net, vat),
      vat_lines: vat_lines
    }
  end

  @doc "VAT lines as stored on an order: string keys and values."
  def snapshot_vat_lines(vat_lines) do
    Enum.map(
      vat_lines,
      &Map.new(&1, fn {key, value} -> {to_string(key), Decimal.to_string(value)} end)
    )
  end

  defp by_rate(lines) do
    lines
    |> Enum.group_by(& &1.vat_rate)
    |> Enum.map(fn {rate, group} ->
      %{rate: rate, net: sum(group, :net), vat: sum(group, :vat), gross: sum(group, :gross)}
    end)
    |> Enum.sort_by(& &1.rate, {:desc, Decimal})
  end

  # Shares of the shipping costs per rate; the last rate takes the rounding rest.
  defp split([], _goods_gross, _shipping_gross), do: %{}

  defp split(groups, goods_gross, shipping_gross) do
    {shares, _rest} =
      groups
      |> Enum.with_index(1)
      |> Enum.map_reduce(shipping_gross, fn {group, index}, rest ->
        share =
          if index == length(groups) or Decimal.equal?(goods_gross, 0),
            do: rest,
            else:
              shipping_gross
              |> Decimal.mult(group.gross)
              |> Decimal.div(goods_gross)
              |> Decimal.round(2)

        {{group.rate, share}, Decimal.sub(rest, share)}
      end)

    Map.new(shares, fn {rate, share} ->
      vat = share |> Decimal.mult(rate) |> Decimal.div(Decimal.add(100, rate)) |> Decimal.round(2)
      {rate, %{net: Decimal.sub(share, vat), vat: vat}}
    end)
  end

  defp sum(items, key),
    do: Enum.reduce(items, Decimal.new(0), &Decimal.add(&2, Map.fetch!(&1, key)))
end
