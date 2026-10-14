defmodule MercatorWeb.OfferLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Consulting.{Conversations, Offers}
  alias Mercator.Sales.Baskets
  alias MercatorWeb.ChatLive

  setup %{conn: conn} do
    gtc_fixture()
    customer = customer_fixture()
    manager = user_fixture(roles: [:sales_manager]) |> Ash.Seed.update!(%{name: "Sepp Fuchs"})
    [variant] = Ash.load!(product_fixture(title: %{"de" => "Zirbenbrett"}), :variants).variants
    %{conn: log_in_user(conn, customer), customer: customer, manager: manager, variant: variant}
  end

  defp offer(context, attrs \\ %{}, send? \\ true) do
    {:ok, offer} = Offers.create(context.customer.id, context.manager, attrs)
    {:ok, offer} = Offers.add_product(offer, context.variant.id, 3, context.manager)
    {:ok, offer} = Offers.update(offer, %{note: "Gerne für Sie gerechnet."}, context.manager)

    if send? do
      {:ok, offer} = Offers.submit(offer, context.manager)
      offer
    else
      offer
    end
  end

  test "the account lists sent offers only", %{conn: conn} = context do
    sent = offer(context)
    draft = offer(context, %{}, false)

    {:ok, view, _html} = live(conn, ~p"/account/offers")
    assert has_element?(view, "#offers a[href='/account/offers/#{sent.id}']", sent.number)
    refute has_element?(view, "#offers a[href='/account/offers/#{draft.id}']")

    {:ok, _view, _html} = live(conn, ~p"/account/offers/#{draft.id}") |> follow_redirect(conn)
  end

  test "accepting an offer orders it at its prices",
       %{conn: conn, customer: customer} = context do
    offer = offer(context)
    Baskets.add({:user, customer}, context.variant.id, 1)

    {:ok, view, _html} = live(conn, ~p"/account/offers/#{offer.id}")
    assert has_element?(view, "#offer-note", "Gerne für Sie gerechnet.")
    assert has_element?(view, "#offer-items", "Zirbenbrett")

    {:ok, checkout, _html} =
      view |> element("#accept-offer") |> render_click() |> follow_redirect(conn)

    assert has_element?(checkout, "#checkout-offer", offer.number)
    assert has_element?(checkout, "#checkout-items", "Zirbenbrett")
    assert has_element?(checkout, "#back-to-offer")

    checkout |> form("#checkout-form", checkout: %{shipping_method: "pickup"}) |> render_change()

    {:ok, order_view, _html} =
      checkout
      |> form("#checkout-form", checkout: %{gtc: "true", payment_method: "on_pickup"})
      |> render_submit()
      |> follow_redirect(conn)

    assert has_element?(order_view, "#order-items", "Zirbenbrett")
    assert {:ok, %{state: :accepted}} = Offers.get(offer.id, customer)
    assert length(Baskets.get({:user, customer}).items) == 1

    {:ok, view, _html} = live(conn, ~p"/account/offers/#{offer.id}")
    refute has_element?(view, "#accept-offer")
    assert has_element?(view, "#offer-order")
  end

  test "an expired offer cannot be accepted", %{conn: conn} = context do
    offer = offer(context)
    Ash.Seed.update!(offer, %{valid_until: Date.add(Mercator.Clock.today(), -1)})

    {:ok, view, _html} = live(conn, ~p"/account/offers/#{offer.id}")
    refute has_element?(view, "#accept-offer")
    assert has_element?(view, "#offer-expired")

    assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/checkout?offer=#{offer.id}")
    assert to == ~p"/account/offers/#{offer.id}"
  end

  test "the offer appears as a card in the customer's chat", %{conn: conn} = context do
    {:ok, conversation} = Conversations.start({:user, context.customer}, "Angebot bitte")
    {:ok, chat, _html} = live_isolated(conn, ChatLive)

    offer = offer(context, %{conversation_id: conversation.id})

    assert has_element?(
             chat,
             ~s(#chat-messages a[href="/account/offers/#{offer.id}"]),
             offer.number
           )
  end
end
