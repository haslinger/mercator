defmodule Mercator.Sales.BasketsTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Sales.{BasketPricing, Baskets}

  setup do
    boards =
      product_fixture(
        kind: :variants,
        variants: [
          %{
            number: "DIELE-4M",
            unit: :piece,
            prices: [%{amount: "24.80"}, %{amount: "22.00", min_quantity: 50}]
          },
          %{number: "DIELE-5M", unit: :piece, prices: [%{amount: "31.00"}]}
        ]
      )

    firewood_tax = tax_class_fixture(rate: 13)

    firewood =
      product_fixture(
        tax_class_id: firewood_tax.id,
        variants: [%{number: "SCHEIT", unit: :rm, prices: [%{amount: "109"}]}]
      )

    [diele4, diele5] = Ash.load!(boards, :variants).variants
    [scheit] = Ash.load!(firewood, :variants).variants

    %{
      owner: {:session, "token-#{System.unique_integer([:positive])}"},
      diele4: diele4,
      diele5: diele5,
      scheit: scheit
    }
  end

  test "adds items and merges identical ones", %{owner: owner, diele4: diele4, diele5: diele5} do
    assert {:ok, _} = Baskets.add(owner, diele4.id, "2")
    assert {:ok, _} = Baskets.add(owner, diele4.id, 3)
    assert {:ok, _} = Baskets.add(owner, diele5.id, 1)

    basket = Baskets.get(owner)
    assert Baskets.count(owner) == 2
    assert Enum.find(basket.items, &(&1.variant_id == diele4.id)).quantity |> Decimal.equal?(5)
  end

  test "whole numbers for pieces, decimals for measured units", %{
    owner: owner,
    diele4: diele4,
    scheit: scheit
  } do
    assert {:error, "Bitte eine ganze Zahl eingeben."} =
             Gettext.with_locale(MercatorWeb.Gettext, "de", fn ->
               Baskets.add(owner, diele4.id, "1,5")
             end)

    assert {:ok, item} = Baskets.add(owner, scheit.id, "2,5")
    assert Decimal.equal?(item.quantity, Decimal.new("2.5"))
    assert {:error, _} = Baskets.add(owner, scheit.id, "0")
  end

  test "only active products can be added", %{owner: owner} do
    draft = product_fixture(state: :draft)
    [variant] = Ash.load!(draft, :variants, authorize?: false).variants

    assert {:error, _} = Baskets.add(owner, variant.id, 1)
  end

  test "configurable products are added with their normalised configuration", %{owner: owner} do
    product = configurable_product_fixture()
    [variant] = Ash.load!(product, :variants).variants

    assert {:ok, item} =
             Baskets.add(owner, variant.id, 2, %{"species" => "oak", "length" => "1999"})

    assert item.selections["length"] == "2000"
    assert item.selections["surface"] == "rough"
    assert String.starts_with?(item.config_number, product.number <> "-")

    # the same configuration is merged, a different one is a new item
    assert {:ok, _} = Baskets.add(owner, variant.id, 1, %{"species" => "oak", "length" => "2000"})
    assert {:ok, _} = Baskets.add(owner, variant.id, 1, %{"species" => "spruce"})
    assert Baskets.count(owner) == 2

    assert {:error, _} = Baskets.add(owner, variant.id, 1, %{"length" => "99999"})
  end

  test "updates and removes items only in the owner's basket", %{owner: owner, diele4: diele4} do
    {:ok, item} = Baskets.add(owner, diele4.id, 1)
    other = {:session, "someone-else"}

    assert {:error, _} = Baskets.update_quantity(other, item.id, 10)
    assert {:error, _} = Baskets.remove(other, item.id)

    assert {:ok, _} = Baskets.update_quantity(owner, item.id, "4")
    assert hd(Baskets.get(owner).items).quantity |> Decimal.equal?(4)

    assert :ok = Baskets.remove(owner, item.id)
    assert Baskets.count(owner) == 0
  end

  test "at login the visitor basket moves into the user's basket", %{
    owner: {:session, token} = visitor,
    diele4: diele4,
    diele5: diele5
  } do
    user = user_fixture()
    {:ok, _} = Baskets.add({:user, user}, diele4.id, 1)
    {:ok, _} = Baskets.add(visitor, diele4.id, 2)
    {:ok, _} = Baskets.add(visitor, diele5.id, 1)

    assert :ok = Baskets.merge(token, user)

    basket = Baskets.get({:user, user})
    assert length(basket.items) == 2
    assert Enum.find(basket.items, &(&1.variant_id == diele4.id)).quantity |> Decimal.equal?(3)
    assert Baskets.get(visitor) == nil
  end

  test "prices are calculated live with graduated prices and VAT per rate", %{
    owner: owner,
    diele4: diele4,
    scheit: scheit
  } do
    {:ok, _} = Baskets.add(owner, diele4.id, 50)
    {:ok, _} = Baskets.add(owner, scheit.id, 2)

    pricing = owner |> Baskets.get() |> BasketPricing.calculate()

    # 50 × 22.00 (graduated) = 1100 net at 20 %; 2 × 109 = 218 net at 13 %
    assert Decimal.equal?(pricing.net, Decimal.new("1318.00"))
    assert [{rate20, vat20}, {rate13, vat13}] = pricing.vat_by_rate
    assert Decimal.equal?(rate20, 20) and Decimal.equal?(vat20, Decimal.new("220.00"))
    assert Decimal.equal?(rate13, 13) and Decimal.equal?(vat13, Decimal.new("28.34"))
    assert Decimal.equal?(pricing.gross, Decimal.new("1566.34"))
  end

  test "deletes abandoned visitor baskets", %{owner: owner, diele4: diele4} do
    {:ok, _} = Baskets.add(owner, diele4.id, 1)

    Baskets.delete_abandoned(30)
    assert Baskets.get(owner)

    Baskets.delete_abandoned(-1)
    assert Baskets.get(owner) == nil
  end
end
