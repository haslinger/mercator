defmodule MercatorWeb.OfferPrintControllerTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Consulting.Offers

  setup do
    customer = customer_fixture(%{name: "Karla Dachs", street: "Biberweg 7"})
    consultant = user_fixture(roles: [:sales])
    [variant] = Ash.load!(product_fixture(title: %{"de" => "Zirbenbrett"}), :variants).variants

    {:ok, offer} = Offers.create(customer.id, consultant, %{note: "Wie besprochen."})
    {:ok, offer} = Offers.add_product(offer, variant.id, 2, consultant)
    %{customer: customer, consultant: consultant, offer: offer}
  end

  test "the customer prints their sent offer", %{conn: conn} = context do
    path = ~p"/account/offers/#{context.offer.id}/print"

    # not before it is sent
    assert conn |> log_in_user(context.customer) |> get(path) |> response(404)

    {:ok, _} = Offers.submit(context.offer, context.consultant)
    html = conn |> log_in_user(context.customer) |> get(path) |> html_response(200)

    document = LazyHTML.from_document(html)
    assert LazyHTML.text(LazyHTML.query(document, "#offer-customer")) =~ "Biberweg 7"
    assert LazyHTML.text(LazyHTML.query(document, "#offer-lines")) =~ "Zirbenbrett"
    assert LazyHTML.text(LazyHTML.query(document, "#offer-gross")) =~ "240,00"
    assert LazyHTML.text(LazyHTML.query(document, "#offer-note")) =~ "Wie besprochen."
    refute html =~ ~s(id="chat-widget")

    # nobody else
    assert conn |> log_in_user(customer_fixture()) |> get(path) |> response(404)
    assert conn |> get(path) |> redirected_to() == ~p"/sign-in"
  end

  test "staff print drafts too; customers cannot use the staff route", %{conn: conn} = context do
    path = ~p"/admin/offers/#{context.offer.id}/print"

    assert conn |> log_in_user(context.consultant) |> get(path) |> html_response(200) =~
             "Zirbenbrett"

    assert conn |> log_in_user(context.customer) |> get(path) |> response(404)
  end
end
