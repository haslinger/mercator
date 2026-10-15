defmodule Mercator.Sales.ShippingTest do
  use ExUnit.Case, async: true

  alias Mercator.Sales.Shipping

  doctest Shipping

  defp products(kinds), do: Enum.map(kinds, &%{shipping: &1})

  describe "methods_for/1" do
    test "parcel goods can be sent as a parcel or picked up" do
      assert Shipping.methods_for(products([:parcel, :parcel])) == [:parcel, :pickup]
    end

    test "one freight item excludes the parcel" do
      assert Shipping.methods_for(products([:parcel, :freight])) == [:freight, :pickup]
    end

    test "one pickup-only item forces pickup" do
      assert Shipping.methods_for(products([:freight, :pickup_only])) == [:pickup]
    end

    test "services don't need shipping" do
      assert Shipping.methods_for(products([:none])) == [:pickup]
      assert Shipping.methods_for(products([:none, :parcel])) == [:parcel, :pickup]
    end
  end

  describe "cost/3" do
    test "parcel per country zone, free from an order value" do
      assert {:ok, %{gross: gross, estimate?: false}} =
               Shipping.cost(:parcel, "AT", Decimal.new("100"))

      assert Decimal.equal?(gross, "9.90")

      assert {:ok, %{gross: gross}} = Shipping.cost(:parcel, "AT", Decimal.new("250"))
      assert Decimal.equal?(gross, 0)

      assert {:ok, %{gross: gross}} = Shipping.cost(:parcel, "IT", Decimal.new("250"))
      assert Decimal.equal?(gross, "14.90")
    end

    test "freight costs are estimates" do
      assert {:ok, %{gross: gross, estimate?: true}} =
               Shipping.cost(:freight, "DE", Decimal.new("5000"))

      assert Decimal.equal?(gross, "189")
    end

    test "a rate is a fixed amount plus a percentage of the goods (#112)" do
      assert Decimal.equal?(
               Shipping.rate_cost(%{gross: "189", percent: "3"}, Decimal.new("5000")),
               "339"
             )

      # without a percentage, the fixed amount
      assert Decimal.equal?(Shipping.rate_cost(%{gross: "9.90"}, Decimal.new("100")), "9.90")
    end

    test "pickup is free everywhere" do
      assert {:ok, %{gross: gross}} = Shipping.cost(:pickup, "NL", Decimal.new("10"))
      assert Decimal.equal?(gross, 0)
    end

    test "no delivery to other countries" do
      assert {:error, :not_available} = Shipping.cost(:parcel, "NL", Decimal.new("10"))
    end
  end

  test "free_from/2" do
    assert Decimal.equal?(Shipping.free_from(:parcel, "AT"), "250")
    assert Shipping.free_from(:freight, "AT") == nil
  end

  test "labels" do
    assert Shipping.label(:pickup) == "Abholung"
  end
end
