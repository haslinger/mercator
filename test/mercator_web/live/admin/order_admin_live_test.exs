defmodule MercatorWeb.Admin.OrderAdminLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.{Catalog, Sales}

  setup %{conn: conn} do
    gtc_fixture()
    board = product_fixture(variants: [%{number: "BRETT", stock: 10, prices: [%{amount: "100"}]}])
    [board] = Ash.load!(board, :variants).variants
    sales = user_fixture(roles: [:sales])

    %{conn: log_in_user(conn, sales), sales: sales, board: board}
  end

  describe "access" do
    test "only sales staff and administrators", %{board: board} do
      order = order_fixture(customer_fixture(), board)

      for roles <- [[], [:productmanager]] do
        conn = log_in_user(build_conn(), user_fixture(roles: roles))
        assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/orders")
        assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/orders/#{order.number}")
      end

      conn = log_in_user(build_conn(), user_fixture(roles: [:administrator]))
      assert {:ok, _view, _html} = live(conn, ~p"/admin/orders/#{order.number}")
    end

    test "the sidebar shows orders to sales staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")
      assert has_element?(view, ~s(#admin-nav a[href="/admin/orders"]))
      assert has_element?(view, "#back-button")
    end
  end

  describe "list" do
    test "lists and filters orders", %{conn: conn, board: board, sales: sales} do
      karl = order_fixture(customer_fixture(), board)
      lena = order_fixture(customer_fixture(name: "Lena Igel"), board)
      Sales.ship_order!(lena, actor: sales)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")
      assert has_element?(view, "#orders-#{karl.id}", karl.number)
      assert has_element?(view, "#orders-#{lena.id}", "Lena Igel")

      view |> element("#order-filters") |> render_change(%{"state" => "shipped"})
      assert_patch(view, ~p"/admin/orders?state=shipped")
      refute has_element?(view, "#orders-#{karl.id}")
      assert has_element?(view, "#orders-#{lena.id}")

      {:ok, view, _html} = live(conn, ~p"/admin/orders?q=igel")
      assert has_element?(view, "#orders-#{lena.id}")
      refute has_element?(view, "#orders-#{karl.id}")

      {:ok, view, _html} = live(conn, ~p"/admin/orders?q=nobody-here")
      assert has_element?(view, "#no-orders")
    end
  end

  describe "detail" do
    test "shows the order and moves it along with notes", %{conn: conn, board: board} do
      order = order_fixture(customer_fixture(), board)
      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")

      assert has_element?(view, "#order-number", order.number)
      assert has_element?(view, "#order-items", "BRETT")
      refute has_element?(view, "#to-completed")

      view
      |> form("#transition-form", change: %{note: "Liefertermin KW 44"})
      |> render_submit(%{"to" => "confirmed"})

      assert has_element?(view, "#order-state", "Bestätigt")
      assert has_element?(view, "#order-history", "Liefertermin KW 44")
      refute has_element?(view, "#to-confirmed")
    end

    test "pickup orders are reported ready for pickup", %{conn: conn, board: board} do
      order =
        order_fixture(customer_fixture(), board, %{
          "shipping_method" => "pickup",
          "payment_method" => "on_pickup"
        })

      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")
      assert has_element?(view, "#to-shipped", "Abholbereit melden")

      view |> form("#transition-form") |> render_submit(%{"to" => "shipped"})
      assert has_element?(view, "#order-state", "Abholbereit")
      assert has_element?(view, "#order-history", "Kunde informiert")

      # only "completed" is left, which sends no email
      refute has_element?(view, "#change_notify")
    end

    test "staff can skip the customer email", %{conn: conn, board: board, sales: sales} do
      order = order_fixture(customer_fixture(), board)
      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")

      view
      |> form("#transition-form", change: %{notify: "false"})
      |> render_submit(%{"to" => "confirmed"})

      refute has_element?(view, "#order-history", "Kunde informiert")
      [event] = Ash.load!(order, :events, actor: sales).events
      refute event.customer_notified

      view |> form("#transition-form") |> render_submit(%{"to" => "shipped"})
      assert has_element?(view, "#order-history", "Kunde informiert")
    end

    test "cancelling needs a reason and restores stock", %{conn: conn, board: board} do
      order = order_fixture(customer_fixture(), [{board, 4}])
      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")

      view |> form("#transition-form") |> render_submit(%{"to" => "cancelled"})
      assert has_element?(view, "#order-state", "Eingegangen")

      view
      |> form("#transition-form", change: %{note: "Kunde hat storniert"})
      |> render_submit(%{"to" => "cancelled"})

      assert has_element?(view, "#order-state", "Storniert")
      refute has_element?(view, "#order-actions")
      assert Decimal.equal?(Catalog.get_variant!(board.id, authorize?: false).stock, 10)
    end

    test "confirming freight asks for the final shipping costs", %{conn: conn} do
      house =
        product_fixture(
          shipping: :freight,
          variants: [%{number: "HAUS", prices: [%{amount: "1000"}]}]
        )

      [house] = Ash.load!(house, :variants).variants
      order = order_fixture(customer_fixture(), house)
      {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")

      view |> form("#transition-form") |> render_submit(%{"to" => "confirmed"})
      assert has_element?(view, "#order-state", "Eingegangen")

      view
      |> form("#transition-form", change: %{shipping_gross: "120,00"})
      |> render_submit(%{"to" => "confirmed"})

      assert has_element?(view, "#order-state", "Bestätigt")
      assert has_element?(view, "#order-total", "1.320,00")
    end
  end
end
