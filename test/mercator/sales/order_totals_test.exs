defmodule Mercator.Sales.OrderTotalsTest do
  use ExUnit.Case, async: true

  alias Mercator.Sales.OrderTotals

  defp line(rate, net) do
    net = Decimal.new(net)
    vat = net |> Decimal.mult(rate) |> Decimal.div(100) |> Decimal.round(2)

    %{
      available?: true,
      vat_rate: Decimal.new(rate),
      net: net,
      vat: vat,
      gross: Decimal.add(net, vat)
    }
  end

  test "one VAT rate: shipping costs carry that rate" do
    totals = OrderTotals.calculate(%{lines: [line(20, "100")]}, Decimal.new("9.90"))

    assert Decimal.equal?(totals.goods_gross, "120.00")
    assert Decimal.equal?(totals.gross, "129.90")
    assert [%{rate: rate, net: net, vat: vat}] = totals.vat_lines
    assert Decimal.equal?(rate, 20)
    assert Decimal.equal?(net, "108.25")
    assert Decimal.equal?(vat, "21.65")
  end

  test "several rates: shipping costs split by the gross value of the goods" do
    # 120 gross at 20 %, 113 gross at 13 %; shipping 14.90
    totals =
      OrderTotals.calculate(%{lines: [line(20, "100"), line(13, "100")]}, Decimal.new("14.90"))

    assert Decimal.equal?(totals.gross, "247.90")
    assert Decimal.equal?(Decimal.add(totals.net, totals.vat), totals.gross)

    [twenty, thirteen] = totals.vat_lines
    assert Decimal.equal?(twenty.rate, 20)
    # share 14.90 × 120 / 233 = 7.67 → VAT 1.28
    assert Decimal.equal?(twenty.vat, "21.28")
    # share 7.23 → VAT 0.83
    assert Decimal.equal?(thirteen.vat, "13.83")
  end

  test "unavailable lines and free shipping" do
    unavailable = %{available?: false, vat_rate: nil, net: nil, vat: nil, gross: nil}
    totals = OrderTotals.calculate(%{lines: [line(20, "100"), unavailable]}, Decimal.new(0))

    assert Decimal.equal?(totals.gross, "120.00")
  end
end
