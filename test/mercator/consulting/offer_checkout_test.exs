defmodule Mercator.Consulting.OfferCheckoutTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Consulting.{Conversations, Offers}
  alias Mercator.Sales.{Baskets, Checkout}

  setup do
    gtc_fixture()
    [variant] = Ash.load!(product_fixture(title: %{"de" => "Lärchendiele"}), :variants).variants

    %{
      manager: user_fixture(roles: [:sales_manager]),
      customer: customer_fixture(),
      variant: variant
    }
  end

  # 2 × 100 less 10 %, Montage 50, then 5 % overall: 171 + 47.50 net
  defp sent_offer(%{manager: manager, customer: customer, variant: variant}, attrs \\ %{}) do
    {:ok, offer} = Offers.create(customer.id, manager, attrs)
    {:ok, offer} = Offers.add_product(offer, variant.id, 2, manager)
    [item] = offer.items
    {:ok, offer} = Offers.update_item(item, %{discount_percent: "10"}, manager)

    {:ok, offer} =
      Offers.add_text(offer, %{title: "Montage", quantity: 1, unit_net: "50"}, manager)

    {:ok, offer} = Offers.update(offer, %{discount_percent: "5"}, manager)
    {:ok, offer} = Offers.submit(offer, manager)
    offer
  end

  defp place(customer, offer) do
    {:ok, offer} = Offers.for_checkout(offer.id, customer)

    Checkout.place(
      customer,
      %{"gtc" => "true", "shipping_method" => "pickup"},
      {:offer, offer}
    )
  end

  test "ordering an offer: its prices, free items, the basket stays", context do
    %{customer: customer, variant: variant} = context
    offer = sent_offer(context)
    assert Decimal.equal?(offer.net, "218.50")

    Baskets.add({:user, customer}, variant.id, 5)

    assert {:ok, order} = place(customer, offer)
    order = Ash.load!(order, :items, authorize?: false)

    assert order.offer_id == offer.id
    assert Decimal.equal?(order.net, offer.net)
    assert Decimal.equal?(order.gross, offer.gross)

    [product_item, text_item] = order.items
    assert product_item.variant_id == variant.id
    assert Decimal.equal?(product_item.net, "171.00")
    assert text_item.number == nil
    assert text_item.title["de"] == "Montage"
    assert Decimal.equal?(text_item.net, "47.50")

    assert {:ok, %{state: :accepted, accepted_at: %DateTime{}}} = Offers.get(offer.id, customer)
    assert [%{quantity: quantity}] = Baskets.get({:user, customer}).items
    assert Decimal.equal?(quantity, 5)

    # accepted once
    assert {:error, :not_acceptable} = Offers.for_checkout(offer.id, customer)
  end

  test "expired offers and other customers' offers cannot be ordered", context do
    offer = sent_offer(context)
    assert {:error, :not_acceptable} = Offers.for_checkout(offer.id, customer_fixture())

    {:ok, loaded} = Offers.for_checkout(offer.id, context.customer)
    Ash.Seed.update!(offer, %{valid_until: Date.add(Mercator.Clock.today(), -1)})
    assert {:error, :not_acceptable} = Offers.for_checkout(offer.id, context.customer)

    # a checkout page opened before the date passed
    stale = %{loaded | valid_until: Date.add(Mercator.Clock.today(), -1)}

    assert {:error, [{:offer, _message}]} =
             Checkout.place(
               context.customer,
               %{"gtc" => "true", "shipping_method" => "pickup"},
               {:offer, stale}
             )
  end

  test "a sent offer appears as a card in its open conversation", context do
    {:ok, conversation} = Conversations.start({:user, context.customer}, "Angebot bitte")
    offer = sent_offer(context, %{conversation_id: conversation.id})

    assert %{messages: messages} = Conversations.current({:user, context.customer})
    assert Enum.any?(messages, &(&1.offer_id == offer.id and &1.offer.number == offer.number))
  end
end
