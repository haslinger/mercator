defmodule Mercator.Consulting.OfferTotals do
  @moduledoc """
  Totals of an offer (docs/guided-selling-design.md, 3.3).

    * an item's goods amount is quantity × unit price less the item
      discount, rounded to cents
    * the overall discount is taken off each item, rounded to cents
    * VAT is calculated per item on its discounted net amount, like basket
      lines (`Mercator.Catalog.PriceInfo`), so an order placed from the
      offer has exactly the offer's amounts

  Shipping is not part of an offer; the checkout adds it (or the consultant
  adds a free-text item for delivery).
  """

  @hundred Decimal.new(100)

  @doc """
  Returns `%{lines: [%{item, goods, net, vat, gross, vat_rate}], goods_net,
  discount, net, vat, gross, vat_lines: [%{rate, net, vat}]}`.
  """
  def calculate(items, discount_percent) do
    discount_percent = discount_percent || Decimal.new(0)
    lines = Enum.map(items, &line(&1, discount_percent))

    vat_lines =
      lines
      |> Enum.group_by(& &1.vat_rate)
      |> Enum.map(fn {rate, group} ->
        %{rate: rate, net: sum(group, :net), vat: sum(group, :vat)}
      end)
      |> Enum.sort_by(& &1.rate, {:desc, Decimal})

    goods_net = sum(lines, :goods)
    net = sum(lines, :net)
    vat = sum(lines, :vat)

    %{
      lines: lines,
      goods_net: goods_net,
      discount: Decimal.sub(goods_net, net),
      net: net,
      vat: vat,
      gross: Decimal.add(net, vat),
      vat_lines: vat_lines
    }
  end

  defp line(item, discount_percent) do
    goods = item_net(item)
    net = Decimal.sub(goods, percent_of(goods, discount_percent))
    vat = percent_of(net, item.vat_rate)

    %{
      item: item,
      goods: goods,
      net: net,
      vat: vat,
      gross: Decimal.add(net, vat),
      vat_rate: item.vat_rate
    }
  end

  @doc "The net amount of an item: quantity × unit price less its discount."
  def item_net(item) do
    gross = Decimal.mult(item.quantity, item.unit_net)

    gross
    |> Decimal.sub(Decimal.mult(gross, Decimal.div(item.discount_percent || 0, @hundred)))
    |> Decimal.round(2)
  end

  @doc """
  The discount of an item compared with the price list, in percent: the
  item discount and a lowered unit price together. For free-text items
  only the item discount.
  """
  def item_discount(%{list_unit_net: list} = item) when not is_nil(list) do
    if Decimal.gt?(list, 0) do
      paid = Decimal.mult(item.unit_net, factor(item.discount_percent))
      @hundred |> Decimal.mult(Decimal.sub(1, Decimal.div(paid, list))) |> Decimal.round(2)
    else
      item.discount_percent || Decimal.new(0)
    end
  end

  def item_discount(item), do: item.discount_percent || Decimal.new(0)

  @doc """
  The highest discount a customer gets on any item, with the overall
  discount included (#98: above a limit a sales manager approves).
  """
  def max_discount(items, discount_percent) do
    overall = factor(discount_percent)

    items
    |> Enum.map(fn item ->
      combined = Decimal.mult(factor(item_discount(item)), overall)
      @hundred |> Decimal.mult(Decimal.sub(1, combined)) |> Decimal.round(2)
    end)
    |> Enum.max(Decimal, fn -> discount_percent || Decimal.new(0) end)
  end

  @doc "VAT lines as stored on an offer: string keys and values."
  def snapshot_vat_lines(vat_lines) do
    Enum.map(
      vat_lines,
      &Map.new(&1, fn {key, value} -> {to_string(key), Decimal.to_string(value)} end)
    )
  end

  defp factor(nil), do: Decimal.new(1)
  defp factor(percent), do: Decimal.sub(1, Decimal.div(percent, @hundred))

  defp percent_of(amount, percent),
    do: amount |> Decimal.mult(percent) |> Decimal.div(@hundred) |> Decimal.round(2)

  defp sum(items, key),
    do: Enum.reduce(items, Decimal.new(0), &Decimal.add(&2, Map.fetch!(&1, key)))
end
