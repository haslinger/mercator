defmodule Mercator.Sales.CheckoutTest do
  use Mercator.DataCase, async: true
  use Oban.Testing, repo: Mercator.Repo

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.{Accounts, Catalog, Sales}
  alias Mercator.Sales.{Baskets, Checkout}
  alias Mercator.Sales.Workers.SendOrderConfirmation

  @address %{
    name: "Karl Luchs",
    street: "Waldweg 3",
    postcode: "6020",
    city: "Innsbruck",
    country: "AT"
  }

  setup do
    user = user_fixture()
    {:ok, address} = Accounts.create_address(@address, actor: user)
    Ash.Seed.seed!(Sales.Gtc, %{version: ~D[2026-10-01], text: %{"de" => "AGB"}})

    board = product_fixture(variants: [%{number: "BRETT", stock: 10, prices: [%{amount: "100"}]}])
    [board_variant] = Ash.load!(board, :variants).variants

    firewood =
      product_fixture(
        tax_class_id: tax_class_fixture(rate: 13).id,
        variants: [%{number: "SCHEIT", unit: :rm, prices: [%{amount: "100"}]}]
      )

    [firewood_variant] = Ash.load!(firewood, :variants).variants

    %{user: user, address: address, board: board_variant, firewood: firewood_variant}
  end

  defp sent_emails do
    receive do
      {:email, email} -> [email | sent_emails()]
    after
      0 -> []
    end
  end

  defp order!(user, params \\ %{}) do
    {:ok, order} = Checkout.place(user, Map.merge(%{"gtc" => "true"}, params))
    Ash.load!(order, :items, authorize?: false)
  end

  test "prepares defaults: address, parcel, prepayment, totals", %{
    user: user,
    address: address,
    board: board
  } do
    Baskets.add({:user, user}, board.id, 1)
    checkout = Checkout.prepare(user)

    assert checkout.billing_address.id == address.id
    assert checkout.shipping_address.id == address.id
    assert checkout.shipping_methods == [:parcel, :pickup]
    assert checkout.payment_methods == [:prepayment]
    assert Decimal.equal?(checkout.totals.gross, "129.90")
    assert Checkout.problems(checkout, true) == []
    assert [gtc: _] = Checkout.problems(checkout, false)
  end

  test "places an order: snapshot, stock, empty basket, email", %{
    user: user,
    board: board,
    firewood: firewood
  } do
    Baskets.add({:user, user}, board.id, 2)
    Baskets.add({:user, user}, firewood.id, "1.5")

    order = order!(user, %{"note" => "Bitte anrufen"})

    assert order.number =~ ~r/^\d{4}-\d{5}$/
    assert order.state == :placed
    assert order.email == to_string(user.email)
    assert order.billing_address["city"] == "Innsbruck"
    assert order.shipping_method == :parcel
    assert order.note == "Bitte anrufen"
    assert order.gtc_version == ~D[2026-10-01]
    # 240 + 169.50 goods, free parcel from 250
    assert Decimal.equal?(order.gross, "409.50")
    assert Decimal.equal?(order.shipping_gross, 0)
    assert length(order.vat_lines) == 2
    assert [%{number: "BRETT"}, %{number: "SCHEIT", unit: :rm}] = order.items

    assert Decimal.equal?(Catalog.get_variant!(board.id, authorize?: false).stock, 8)
    assert Baskets.get({:user, user}) == nil

    assert_enqueued worker: SendOrderConfirmation, args: %{order_id: order.id}
    assert :ok = perform_job(SendOrderConfirmation, %{order_id: order.id})
    assert Enum.any?(sent_emails(), &(&1.subject =~ order.number))
  end

  test "order numbers are sequential", %{user: user, board: board} do
    Baskets.add({:user, user}, board.id, 1)
    first = order!(user)
    Baskets.add({:user, user}, board.id, 1)
    second = order!(user)

    assert second.sequence == first.sequence + 1
  end

  test "requires the terms, a basket and enough stock", %{user: user, board: board} do
    assert {:error, problems} = Checkout.place(user, %{"gtc" => "true"})
    assert Keyword.has_key?(problems, :basket)

    Baskets.add({:user, user}, board.id, 1)
    assert {:error, [gtc: _]} = Checkout.place(user, %{})

    Catalog.update_variant!(board, %{stock: 0}, authorize?: false)
    assert {:error, [basket: message]} = Checkout.place(user, %{"gtc" => "true"})
    assert message =~ "BRETT"
    assert Sales.list_my_orders!(actor: user) == []
  end

  test "pickup allows payment on pickup; invoice only when approved", %{user: user, board: board} do
    Baskets.add({:user, user}, board.id, 1)

    assert Checkout.prepare(user, %{"shipping_method" => "pickup"}).payment_methods ==
             [:prepayment, :on_pickup]

    user = Accounts.set_invoice_allowed!(user, true, authorize?: false)
    assert :invoice in Checkout.prepare(user).payment_methods

    order = order!(user, %{"shipping_method" => "pickup", "payment_method" => "on_pickup"})
    assert order.shipping_address == nil
    assert Decimal.equal?(order.shipping_gross, 0)
  end

  test "freight goods exclude the parcel", %{user: user} do
    house = product_fixture(shipping: :freight)
    [variant] = Ash.load!(house, :variants).variants
    Baskets.add({:user, user}, variant.id, 1)

    checkout = Checkout.prepare(user, %{"shipping_method" => "parcel"})
    assert checkout.shipping_method == :freight
    assert checkout.shipping_cost.estimate?
  end

  test "delivery only to delivery countries", %{board: board} do
    user = user_fixture()
    Accounts.create_address!(%{@address | country: "NL", postcode: "1011 AB"}, actor: user)
    Baskets.add({:user, user}, board.id, 1)

    checkout = Checkout.prepare(user)
    assert checkout.billing_address.country == "NL"
    assert checkout.shipping_address == nil
    assert Keyword.has_key?(Checkout.problems(checkout, true), :shipping_address)

    assert Checkout.problems(Checkout.prepare(user, %{"shipping_method" => "pickup"}), true) == []
  end

  test "customers see only their own orders; sales staff see all", %{user: user, board: board} do
    Baskets.add({:user, user}, board.id, 1)
    order = order!(user)

    assert {:error, _} = Sales.get_order_by_number(order.number, actor: user_fixture())
    assert {:ok, _} = Sales.get_order_by_number(order.number, actor: user)

    assert {:ok, _} =
             Sales.get_order_by_number(order.number, actor: user_fixture(roles: [:sales]))
  end
end
