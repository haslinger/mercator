defmodule Mercator.Sales.OrderManagementTest do
  use Mercator.DataCase, async: true
  use Oban.Testing, repo: Mercator.Repo

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.{Catalog, Sales}
  alias Mercator.Sales.Workers.SendOrderStatusEmail

  setup do
    gtc_fixture()
    board = product_fixture(variants: [%{number: "BRETT", stock: 10, prices: [%{amount: "100"}]}])
    [board] = Ash.load!(board, :variants).variants

    %{board: board, sales: user_fixture(roles: [:sales]), customer: customer_fixture()}
  end

  describe "search" do
    test "filters by state and text, newest first", %{board: board, sales: sales} do
      karl = customer_fixture()
      lena = customer_fixture(name: "Lena Igel", company: "Igel Bau GmbH")
      first = order_fixture(karl, board)
      second = order_fixture(lena, board)
      Sales.ship_order!(second, actor: sales)

      numbers = fn input ->
        Sales.search_orders!(Map.new(input), actor: sales) |> Enum.map(& &1.number)
      end

      assert numbers.(%{}) |> Enum.take(2) == [second.number, first.number]
      assert numbers.(state: :shipped) |> Enum.member?(second.number)
      refute numbers.(state: :shipped) |> Enum.member?(first.number)
      assert numbers.(query: "igel bau") == [second.number]
      assert numbers.(query: "LENA") == [second.number]
      assert numbers.(query: first.number) == [first.number]
      assert numbers.(query: to_string(karl.email)) == [first.number]
      assert numbers.(query: "100%") == []
    end

    test "filters by period and paginates", %{board: board, sales: sales, customer: customer} do
      order = order_fixture(customer, board)
      today = Date.utc_today()

      assert [_] =
               Sales.search_orders!(%{from: today, to: today, query: order.number}, actor: sales)

      assert [] =
               Sales.search_orders!(%{to: Date.add(today, -1), query: order.number}, actor: sales)

      order_fixture(customer, board)
      page = Sales.search_orders!(actor: sales, page: [limit: 1, count: true])
      assert [_] = page.results
      assert page.count >= 2
    end

    test "the period uses local days", %{board: board, sales: sales, customer: customer} do
      order = order_fixture(customer, board)

      # 23:30 on 13 October in Vienna is 21:30 UTC
      Mercator.Repo.query!("UPDATE orders SET inserted_at = $1 WHERE id = $2", [
        ~U[2026-10-13 21:30:00.000000Z],
        Ecto.UUID.dump!(order.id)
      ])

      find = fn from, to ->
        Sales.search_orders!(%{from: from, to: to, query: order.number}, actor: sales)
      end

      assert [_] = find.(~D[2026-10-13], ~D[2026-10-13])
      assert [] = find.(~D[2026-10-14], nil)
      assert [] = find.(nil, ~D[2026-10-12])
    end

    test "customers find only their own orders", %{board: board, customer: customer} do
      order_fixture(customer_fixture(), board)
      own = order_fixture(customer, board)

      assert Sales.search_orders!(actor: customer) |> Enum.map(& &1.id) == [own.id]
    end
  end

  describe "state changes" do
    test "staff move orders along; each change is recorded", %{
      board: board,
      sales: sales,
      customer: customer
    } do
      order = order_fixture(customer, board)

      order = Sales.confirm_order!(order, %{note: "Liefertermin KW 44"}, actor: sales)
      order = Sales.mark_order_paid!(order, actor: sales)
      order = Sales.ship_order!(order, actor: sales)
      order = Sales.complete_order!(order, actor: sales)
      assert order.state == :completed

      events = Ash.load!(order, :events, actor: sales).events

      assert Enum.map(events, &{&1.from_state, &1.to_state}) ==
               [placed: :confirmed, confirmed: :paid, paid: :shipped, shipped: :completed]

      assert hd(events).note == "Liefertermin KW 44"
      assert hd(events).user_id == sales.id
    end

    test "customers cannot change states; finished orders cannot be cancelled", %{
      board: board,
      sales: sales,
      customer: customer
    } do
      order = order_fixture(customer, board)
      assert {:error, %Ash.Error.Forbidden{}} = Sales.ship_order(order, actor: customer)

      order = order |> Sales.ship_order!(actor: sales) |> Sales.complete_order!(actor: sales)
      assert {:error, _} = Sales.cancel_order(order, %{note: "zu spät"}, actor: sales)
    end

    test "cancelling needs a reason and puts tracked stock back", %{
      board: board,
      sales: sales,
      customer: customer
    } do
      made_to_order = product_fixture(variants: [%{number: "TISCH", prices: [%{amount: "500"}]}])
      [made_to_order] = Ash.load!(made_to_order, :variants).variants

      order = order_fixture(customer, [{board, 3}, {made_to_order, 1}])
      assert Decimal.equal?(Catalog.get_variant!(board.id, authorize?: false).stock, 7)

      assert {:error, _} = Sales.cancel_order(order, %{}, actor: sales)

      order = Sales.cancel_order!(order, %{note: "Kunde storniert"}, actor: sales)
      assert order.state == :cancelled
      assert Decimal.equal?(Catalog.get_variant!(board.id, authorize?: false).stock, 10)
      assert Catalog.get_variant!(made_to_order.id, authorize?: false).stock == nil

      [event] = Ash.load!(order, :events, actor: sales).events
      assert event.note == "Kunde storniert"
    end

    test "confirming a freight order sets the final shipping costs", %{
      sales: sales,
      customer: customer
    } do
      house =
        product_fixture(
          shipping: :freight,
          variants: [%{number: "HAUS", prices: [%{amount: "1000"}]}]
        )

      [house] = Ash.load!(house, :variants).variants
      order = order_fixture(customer, house)
      assert order.shipping_estimate

      assert {:error, error} = Sales.confirm_order(order, actor: sales)
      assert Exception.message(error) =~ "shipping"

      order = Sales.confirm_order!(order, %{shipping_gross: "120"}, actor: sales)
      refute order.shipping_estimate
      assert Decimal.equal?(order.shipping_gross, 120)
      # 1000 net + 20 % = 1200 goods, plus 120 shipping
      assert Decimal.equal?(order.gross, 1320)
      assert Decimal.equal?(order.vat, 220)
      assert [%{"rate" => "20", "net" => "1100.00", "vat" => "220.00"}] = order.vat_lines
    end
  end

  describe "emails about state changes (#74)" do
    defp emails do
      receive do
        {:email, email} -> [email | emails()]
      after
        0 -> []
      end
    end

    defp event(order, sales, state) do
      order
      |> Ash.load!(:events, actor: sales)
      |> Map.fetch!(:events)
      |> Enum.find(&(&1.to_state == state))
    end

    test "confirmation, shipping and cancellation are emailed", %{
      board: board,
      sales: sales,
      customer: customer
    } do
      order = order_fixture(customer, board)
      # drop the account confirmation emails of the fixtures
      _ = emails()
      order = Sales.confirm_order!(order, %{note: "intern: Stammkunde"}, actor: sales)
      confirmed = event(order, sales, :confirmed)
      assert confirmed.customer_notified

      assert_enqueued worker: SendOrderStatusEmail, args: %{event_id: confirmed.id}
      assert :ok = perform_job(SendOrderStatusEmail, %{event_id: confirmed.id})
      [email] = emails()
      assert email.subject =~ "#{order.number} ist bestätigt"
      assert email.to == [{"", to_string(customer.email)}]
      refute email.text_body =~ "Stammkunde"

      order = Sales.mark_order_paid!(order, actor: sales)
      refute event(order, sales, :paid).customer_notified

      order = Sales.ship_order!(order, actor: sales)

      assert :ok =
               perform_job(SendOrderStatusEmail, %{event_id: event(order, sales, :shipped).id})

      assert [%{subject: subject}] = emails()
      assert subject =~ "unterwegs"

      other = order_fixture(customer, board)
      other = Sales.cancel_order!(other, %{note: "Nicht lieferbar"}, actor: sales)
      cancelled = event(other, sales, :cancelled)
      assert :ok = perform_job(SendOrderStatusEmail, %{event_id: cancelled.id})
      [email] = emails()
      assert email.subject =~ "storniert"
      assert email.text_body =~ "Nicht lieferbar"
    end

    test "no email when staff opt out or a pickup order is picked up", %{
      board: board,
      sales: sales,
      customer: customer
    } do
      order = order_fixture(customer, board)
      order = Sales.confirm_order!(order, %{notify: false}, actor: sales)
      refute event(order, sales, :confirmed).customer_notified

      pickup =
        customer
        |> order_fixture(board, %{"shipping_method" => "pickup", "payment_method" => "on_pickup"})
        |> Sales.ship_order!(actor: sales)

      refute event(pickup, sales, :shipped).customer_notified
      refute_enqueued worker: SendOrderStatusEmail
    end
  end
end
