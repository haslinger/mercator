defmodule Mercator.Consulting.OfferTotalsTest do
  use ExUnit.Case, async: true

  alias Mercator.Consulting.OfferTotals

  defp item(attrs) do
    Map.merge(
      %{
        quantity: Decimal.new(1),
        unit_net: Decimal.new(100),
        list_unit_net: Decimal.new(100),
        discount_percent: Decimal.new(0),
        vat_rate: Decimal.new(20)
      },
      Map.new(attrs, fn {key, value} -> {key, Decimal.new(value)} end)
    )
  end

  test "items with discounts, the overall discount per rate, VAT per rate" do
    items = [
      item(quantity: "3", unit_net: "100", discount_percent: "10"),
      item(quantity: "2", unit_net: "50", vat_rate: "10", list_unit_net: "50")
    ]

    totals = OfferTotals.calculate(items, Decimal.new(5))

    # 270.00 at 20 %, 100.00 at 10 %; 5 % off each
    assert Decimal.equal?(totals.goods_net, "370.00")
    assert Decimal.equal?(totals.discount, "18.50")
    assert Decimal.equal?(totals.net, "351.50")
    assert [%{rate: r20, net: n20, vat: v20}, %{rate: r10, net: n10, vat: v10}] = totals.vat_lines

    assert Decimal.equal?(r20, 20) and Decimal.equal?(n20, "256.50") and
             Decimal.equal?(v20, "51.30")

    assert Decimal.equal?(r10, 10) and Decimal.equal?(n10, "95.00") and
             Decimal.equal?(v10, "9.50")

    assert Decimal.equal?(totals.gross, "412.30")
  end

  test "an empty offer" do
    totals = OfferTotals.calculate([], Decimal.new(0))
    assert Decimal.equal?(totals.gross, 0)
    assert totals.vat_lines == []
  end

  describe "discounts compared with the price list (#98)" do
    test "a lowered unit price counts as a discount" do
      assert Decimal.equal?(OfferTotals.item_discount(item(unit_net: "88")), 12)
    end

    test "item and overall discount combine" do
      # 1 - 0.92 × 0.95 = 12.6 %
      max = OfferTotals.max_discount([item(discount_percent: "8")], Decimal.new(5))
      assert Decimal.equal?(max, "12.60")
    end

    test "free-text items only have their own discount" do
      text = %{item(discount_percent: "3") | list_unit_net: nil}
      assert Decimal.equal?(OfferTotals.max_discount([text], Decimal.new(0)), 3)
    end

    test "without items the overall discount" do
      assert Decimal.equal?(OfferTotals.max_discount([], Decimal.new(7)), 7)
    end
  end
end
