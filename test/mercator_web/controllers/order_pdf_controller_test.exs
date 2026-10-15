defmodule MercatorWeb.OrderPdfControllerTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Sales
  alias MercatorWeb.Documents

  setup do
    gtc_fixture()
    customer = customer_fixture(%{name: "Karla Dachs", street: "Biberweg 7"})
    [variant] = Ash.load!(product_fixture(title: %{"de" => "Zirbenbrett"}), :variants).variants
    order = order_fixture(customer, variant, %{"note" => "Bitte anrufen."})
    %{customer: customer, order: order}
  end

  test "the customer downloads the confirmation of their order", %{conn: conn} = context do
    conn =
      conn
      |> log_in_user(context.customer)
      |> get(~p"/account/orders/#{context.order.number}/pdf")

    assert "%PDF-" <> _ = response(conn, 200)

    assert get_resp_header(conn, "content-disposition") ==
             [~s(attachment; filename="Auftragsbestaetigung-#{context.order.number}.pdf")]
  end

  test "staff download any order; others get nothing", %{conn: conn} = context do
    path = ~p"/admin/orders/#{context.order.number}/pdf"

    assert "%PDF-" <> _ =
             conn |> log_in_user(user_fixture(roles: [:sales])) |> get(path) |> response(200)

    assert conn |> log_in_user(customer_fixture()) |> get(path) |> response(404)
    assert conn |> get(path) |> redirected_to() == ~p"/sign-in"
  end

  test "the document data: billing address, items, payment, note", context do
    order = Sales.get_order_by_number!(context.order.number, authorize?: false, load: [:items])
    data = Gettext.with_locale(MercatorWeb.Gettext, "de", fn -> Documents.order_data(order) end)

    assert data.title == "Auftragsbestätigung #{order.number}"
    assert "Biberweg 7" in data.recipient
    assert "Ihre Anmerkung: Bitte anrufen." in data.intro
    assert [[_pos, _qty, %{title: "Zirbenbrett"}, unit, "20 %", _amount]] = data.rows
    assert unit =~ "120,00"
    assert [%{heading: "Zahlung: " <> _} | _] = data.sections
    assert %{label: "Gesamt", value: "129,90 €", strong: true} in data.sums
  end
end
