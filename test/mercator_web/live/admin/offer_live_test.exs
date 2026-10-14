defmodule MercatorWeb.Admin.OfferLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Consulting.{Conversations, Offers}
  alias Mercator.Sales.Baskets

  setup %{conn: conn} do
    consultant = user_fixture(roles: [:sales]) |> Ash.Seed.update!(%{name: "Sepp Fuchs"})
    customer = user_fixture() |> Ash.Seed.update!(%{name: "Karla Dachs"})
    %{conn: log_in_user(conn, consultant), consultant: consultant, customer: customer}
  end

  defp draft(%{customer: customer, consultant: consultant}) do
    {:ok, offer} = Offers.create(customer.id, consultant)
    offer
  end

  defp variant(attrs \\ %{}) do
    [variant] = Ash.load!(product_fixture(attrs), :variants).variants
    variant
  end

  test "only sales staff and administrators" do
    for roles <- [[], [:contentmanager]] do
      conn = log_in_user(build_conn(), user_fixture(roles: roles))
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/offers")
    end
  end

  describe "list" do
    test "offers with state filter; a new offer starts with the customer",
         %{conn: conn} = context do
      offer = draft(context)

      {:ok, view, _html} = live(conn, ~p"/admin/offers")
      assert has_element?(view, "#offers a[href='/admin/offers/#{offer.id}']", offer.number)

      view |> form("#offer-filters", %{"state" => "sent"}) |> render_change()
      assert_patch(view, ~p"/admin/offers?state=sent")
      refute has_element?(view, "#offers a[href='/admin/offers/#{offer.id}']")

      view |> element("#new-offer") |> render_click()
      view |> form("#customer-search", %{"q" => "Dachs"}) |> render_change()
      view |> element("#customer-#{context.customer.id}") |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"^/admin/offers/[0-9a-f-]{36}$"
    end
  end

  describe "editor" do
    test "products, free items, quantities and totals", %{conn: conn} = context do
      offer = draft(context)
      variant = variant(title: %{"de" => "Lärchendiele"}, number: "LD-1")

      {:ok, view, _html} = live(conn, ~p"/admin/offers/#{offer.id}")
      assert has_element?(view, "#no-items")

      view |> element("#add-product") |> render_click()
      view |> form("#product-search", %{"q" => "LD-1"}) |> render_change()
      view |> element("#add-variant-#{variant.id}") |> render_click()
      refute has_element?(view, "#product-modal")

      [item] = Offers.get(offer.id, context.consultant) |> elem(1) |> Map.fetch!(:items)
      assert has_element?(view, "#item-form-#{item.id}", "Lärchendiele")

      view
      |> form("#item-form-#{item.id}", %{"quantity" => "3"})
      |> render_change()

      assert has_element?(view, "#item-net-#{item.id}", "300,00")
      assert has_element?(view, "#offer-gross", "360,00")

      view |> element("#add-text") |> render_click()
      {:ok, %{items: [_, text]}} = Offers.get(offer.id, context.consultant)

      view
      |> form("#item-form-#{text.id}", %{
        "title" => "Montage",
        "quantity" => "2",
        "unit_net" => "45,50"
      })
      |> render_change()

      assert has_element?(view, "#item-net-#{text.id}", "91,00")

      view |> element("#remove-item-#{text.id}") |> render_click()
      refute has_element?(view, "#item-form-#{text.id}")
    end

    test "the customer's basket is taken over", %{conn: conn, customer: customer} = context do
      Baskets.add({:user, customer}, variant(title: %{"de" => "Zirbenbrett"}).id, 2)

      {:ok, view, _html} = live(conn, ~p"/admin/offers/#{draft(context).id}")
      view |> element("#import-basket") |> render_click()
      assert has_element?(view, "#offer-items", "Zirbenbrett")
    end

    test "sending; afterwards revising", %{conn: conn} = context do
      {:ok, offer} = Offers.add_product(draft(context), variant().id, 1, context.consultant)

      {:ok, view, _html} = live(conn, ~p"/admin/offers/#{offer.id}")
      refute has_element?(view, "#approval-hint")
      view |> element("#submit-offer") |> render_click()
      assert has_element?(view, "#offer-state", "Versendet")
      refute has_element?(view, "#offer-header form")

      view |> element("#revise-offer") |> render_click()
      {path, _flash} = assert_redirect(view)
      assert path != ~p"/admin/offers/#{offer.id}"
    end

    test "a large discount needs a sales manager's approval (#98)", %{conn: conn} = context do
      {:ok, offer} = Offers.add_product(draft(context), variant().id, 1, context.consultant)

      {:ok, view, _html} = live(conn, ~p"/admin/offers/#{offer.id}")
      view |> form("#offer-header", offer: %{discount_percent: "15"}) |> render_change()
      assert has_element?(view, "#approval-hint")
      assert has_element?(view, "#submit-offer", "Zur Freigabe")

      view |> element("#submit-offer") |> render_click()
      assert has_element?(view, "#offer-state", "Wartet auf Freigabe")
      refute has_element?(view, "#approve-offer")

      manager = user_fixture(roles: [:sales_manager])

      {:ok, manager_view, _html} =
        live(log_in_user(build_conn(), manager), ~p"/admin/offers/#{offer.id}")

      manager_view |> element("#reject-offer") |> render_click()
      manager_view |> form("#reject-form", %{"note" => "Maximal 10 %"}) |> render_submit()
      assert has_element?(manager_view, "#offer-state", "Entwurf")

      {:ok, view, _html} = live(conn, ~p"/admin/offers/#{offer.id}")
      assert has_element?(view, "#approval-note", "Maximal 10 %")
      view |> element("#submit-offer") |> render_click()

      {:ok, manager_view, _html} =
        live(log_in_user(build_conn(), manager), ~p"/admin/offers/#{offer.id}")

      manager_view |> element("#approve-offer") |> render_click()
      assert has_element?(manager_view, "#offer-state", "Versendet")
    end
  end

  describe "sales desk" do
    test "an offer from the conversation of a signed-in customer", %{conn: conn} = context do
      {:ok, conversation} = Conversations.start({:user, context.customer}, "Angebot bitte")
      offer = draft(context)

      {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
      assert has_element?(desk, "#customer-offers a[href='/admin/offers/#{offer.id}']")
      assert has_element?(desk, "#desk-conversation-#{conversation.id}", "Karla Dachs")

      desk |> element("#create-offer") |> render_click()
      {path, _flash} = assert_redirect(desk)

      {:ok, created} =
        Offers.get(String.replace_prefix(path, "/admin/offers/", ""), context.consultant)

      assert created.conversation_id == conversation.id
    end

    test "visitors need to sign in first", %{conn: conn} do
      {:ok, conversation} = Conversations.start({:session, "visitor-offers"}, "Hallo")
      {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
      refute has_element?(desk, "#create-offer")
    end
  end
end
