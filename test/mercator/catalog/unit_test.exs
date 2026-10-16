defmodule Mercator.Catalog.UnitTest do
  use ExUnit.Case, async: true

  alias Mercator.Catalog.Unit

  test "every unit has a symbol, a dimension and a label" do
    for unit <- Unit.values() do
      assert is_binary(Unit.symbol(unit))
      assert Unit.dimension(unit) in [:count, :length, :area, :volume, :mass]
      assert is_boolean(Unit.decimals?(unit))
      assert is_binary(Unit.label(unit))
    end
  end

  test "countable units do not allow decimals, measured units do" do
    refute Unit.decimals?(:piece)
    refute Unit.decimals?(:pallet)
    assert Unit.decimals?(:m3)
    assert Unit.decimals?(:rm)
  end

  test "labels are translated" do
    Gettext.with_locale(MercatorWeb.Gettext, "de", fn ->
      assert Unit.label(:piece) == "Stück"
      assert Unit.label(:rm) =~ "Raummeter"
    end)

    Gettext.with_locale(MercatorWeb.Gettext, "en", fn ->
      assert Unit.label(:piece) == "piece"
    end)
  end

  test "symbols of counted units are translated" do
    Gettext.with_locale(MercatorWeb.Gettext, "de", fn ->
      assert Enum.map([:piece, :pallet, :sack, :m3], &Unit.symbol/1) == [
               "Stk.",
               "Pal.",
               "Sack",
               "m³"
             ]
    end)

    Gettext.with_locale(MercatorWeb.Gettext, "en", fn ->
      assert Enum.map([:piece, :pallet, :sack, :m3], &Unit.symbol/1) == [
               "pc.",
               "pallet",
               "sack",
               "m³"
             ]
    end)
  end
end
