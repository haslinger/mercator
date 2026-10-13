defmodule MercatorWeb.FormatTest do
  use ExUnit.Case, async: true

  doctest MercatorWeb.Format

  alias MercatorWeb.Format

  test "money with thousands separators and rounding" do
    assert Format.money(Decimal.new("1234567.891"), "de") == "1.234.567,89 €"
    assert Format.money(Decimal.new("0.5"), "de") == "0,50 €"
    assert Format.money(Decimal.new("49900"), "en") == "€49,900.00"
    assert Format.money(nil, "de") == nil
  end

  test "quantities keep up to three decimals for measured units" do
    assert Format.quantity(Decimal.new("2.125"), :m3, "de") == "2,125"
    assert Format.quantity(Decimal.new("10"), :rm, "en") == "10"
    assert Format.quantity(Decimal.new("1500"), :kg, "de") == "1.500"
  end
end
