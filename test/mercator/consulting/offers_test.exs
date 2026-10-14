defmodule Mercator.Consulting.OffersTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Consulting.{Conversations, Offer, Offers}
  alias Mercator.Sales.Baskets

  setup do
    %{
      consultant: user_fixture(roles: [:sales]),
      manager: user_fixture(roles: [:sales_manager]),
      customer: user_fixture()
    }
  end

  defp variant(attrs \\ %{}) do
    [variant] = Ash.load!(product_fixture(attrs), :variants, authorize?: false).variants
    variant
  end

  defp draft(%{customer: customer, consultant: consultant}) do
    {:ok, offer} = Offers.create(customer.id, consultant)
    offer
  end

  defp with_product(context, quantity \\ 2) do
    {:ok, offer} = Offers.add_product(draft(context), variant().id, quantity, context.consultant)
    offer
  end

  describe "creating" do
    test "numbers per year, validity and language", %{customer: customer, consultant: consultant} do
      {:ok, first} = Offers.create(customer.id, consultant)
      {:ok, second} = Offers.create(customer.id, consultant)

      assert first.number =~ ~r/^A-\d{4}-\d{5}$/
      assert second.sequence == first.sequence + 1
      assert first.state == :draft
      assert first.version == 1
      assert first.consultant_id == consultant.id
      assert first.locale == "de"
      assert first.valid_until == Date.add(Mercator.Clock.today(), 30)
    end

    test "from a conversation; visitors have to sign in first", %{
      customer: customer,
      consultant: consultant
    } do
      {:ok, conversation} = Conversations.start({:user, customer}, "Angebot bitte")
      {:ok, offer} = Offers.create_for_conversation(conversation, consultant)
      assert offer.conversation_id == conversation.id

      {:ok, visit} = Conversations.start({:session, "visitor-offer"}, "Hallo")
      assert Offers.create_for_conversation(visit, consultant) == {:error, :visitor}
    end

    test "only sales staff", %{customer: customer} do
      assert {:error, %Ash.Error.Forbidden{}} = Offers.create(customer.id, customer)

      assert {:error, %Ash.Error.Forbidden{}} =
               Offers.create(customer.id, user_fixture(roles: [:contentmanager]))
    end
  end

  describe "items" do
    test "a product at its price, with totals", context do
      offer = with_product(context)

      assert [item] = offer.items
      assert item.kind == :product
      assert item.title =~ "Produkt"
      assert Decimal.equal?(item.unit_net, 100) and Decimal.equal?(item.list_unit_net, 100)
      assert Decimal.equal?(offer.net, 200)
      assert Decimal.equal?(offer.vat, 40)
      assert Decimal.equal?(offer.gross, 240)
      assert [%{"rate" => "20", "net" => "200.00"}] = offer.vat_lines
    end

    test "a configurable product with its configuration", context do
      [variant] = Ash.load!(configurable_product_fixture(), :variants).variants

      {:ok, offer} =
        Offers.add_product(draft(context), variant.id, 2, context.consultant, %{
          "species" => "oak"
        })

      assert [item] = offer.items
      assert item.description =~ "species: oak"
      assert item.selections["species"] == "oak"
      assert is_binary(item.number)
      assert Decimal.gt?(item.unit_net, 0)
    end

    test "free-text items, discounts and the overall discount", context do
      {:ok, offer} =
        Offers.add_text(
          draft(context),
          %{title: "Montage", quantity: 4, unit: :piece, unit_net: "50", discount_percent: "10"},
          context.consultant
        )

      [item] = offer.items
      assert item.kind == :text
      assert Decimal.equal?(item.vat_rate, 20)
      assert Decimal.equal?(offer.net, 180)

      {:ok, offer} = Offers.update(offer, %{discount_percent: "5"}, context.consultant)
      assert Decimal.equal?(offer.net, 171)
    end

    test "a new quantity is priced again unless the consultant set the price", context do
      variant =
        variant(variants: [%{prices: [%{amount: "100"}, %{amount: "80", min_quantity: 10}]}])

      {:ok, offer} = Offers.add_product(draft(context), variant.id, 2, context.consultant)
      [item] = offer.items

      {:ok, offer} = Offers.update_item(item, %{quantity: 10}, context.consultant)
      [item] = offer.items
      assert Decimal.equal?(item.unit_net, 80)

      {:ok, offer} = Offers.update_item(item, %{unit_net: "75"}, context.consultant)
      [item] = offer.items
      {:ok, offer} = Offers.update_item(item, %{quantity: 2}, context.consultant)
      [item] = offer.items
      assert Decimal.equal?(item.list_unit_net, 100)
      assert Decimal.equal?(item.unit_net, 75)

      {:ok, offer} = Offers.remove_item(item, context.consultant)
      assert offer.items == []
      assert Decimal.equal?(offer.gross, 0)
    end

    test "the customer's basket is taken over", %{customer: customer} = context do
      Baskets.add({:user, customer}, variant().id, 3)
      Baskets.add({:user, customer}, variant(state: :discontinued).id, 1)

      {:ok, offer, 1} = Offers.import_basket(draft(context), context.consultant)
      assert [%{quantity: quantity}] = offer.items
      assert Decimal.equal?(quantity, 3)
    end
  end

  describe "submitting and approval (#98)" do
    test "an empty offer cannot be submitted", context do
      assert {:error, %Ash.Error.Invalid{}} = Offers.submit(draft(context), context.consultant)
    end

    test "small discounts are sent at once; items are then fixed", context do
      offer = with_product(context)
      [item] = offer.items
      {:ok, item_offer} = Offers.update_item(item, %{discount_percent: "10"}, context.consultant)

      {:ok, offer} = Offers.submit(item_offer, context.consultant)
      assert offer.state == :sent
      assert offer.sent_at

      [item] = offer.items

      assert {:error, %Ash.Error.Invalid{}} =
               Offers.update_item(item, %{quantity: 5}, context.consultant)
    end

    test "larger discounts wait for a sales manager", context do
      {:ok, offer} =
        Offers.update(with_product(context), %{discount_percent: "15"}, context.consultant)

      {:ok, offer} = Offers.submit(offer, context.consultant)
      assert offer.state == :pending_approval

      assert {:error, %Ash.Error.Forbidden{}} = Offers.approve(offer, context.consultant)

      {:ok, offer} = Offers.reject(offer, "Höchstens 10 %", context.manager)
      assert offer.state == :draft
      assert offer.approval_note == "Höchstens 10 %"

      {:ok, offer} = Offers.submit(offer, context.consultant)
      {:ok, offer} = Offers.approve(offer, context.manager)
      assert offer.state == :sent
      assert offer.approved_by.id == context.manager.id
    end

    test "a sales manager's own offers need no approval", context do
      {:ok, offer} = Offers.create(context.customer.id, context.manager)
      {:ok, offer} = Offers.add_product(offer, variant().id, 1, context.manager)
      {:ok, offer} = Offers.update(offer, %{discount_percent: "30"}, context.manager)

      assert {:ok, %{state: :sent}} = Offers.submit(offer, context.manager)
    end
  end

  describe "customers" do
    test "see their offers once sent", %{customer: customer} = context do
      offer = with_product(context)
      assert Ash.read!(Offer, action: :mine, actor: customer) == []
      assert {:ok, nil} = Offers.get(offer.id, customer)

      {:ok, offer} = Offers.submit(offer, context.consultant)
      assert [%{id: id}] = Ash.read!(Offer, action: :mine, actor: customer)
      assert id == offer.id
      assert {:ok, %{items: [_item]}} = Offers.get(offer.id, customer)

      assert Ash.read!(Offer, action: :mine, actor: user_fixture()) == []
    end
  end

  describe "afterwards" do
    test "revising creates the next version with copied items", context do
      {:ok, sent} = Offers.submit(with_product(context), context.consultant)

      {:ok, revision} = Offers.revise(sent, context.consultant)
      assert revision.state == :draft
      assert revision.number == sent.number
      assert revision.version == 2
      assert revision.previous_offer_id == sent.id
      assert Offer.display_number(revision) == "#{sent.number}/2"
      assert [%{title: title}] = revision.items
      assert title == hd(sent.items).title
      assert Decimal.equal?(revision.gross, sent.gross)

      assert {:ok, %{state: :revised}} = Offers.get(sent.id, context.consultant)
    end

    test "withdrawing", context do
      {:ok, sent} = Offers.submit(with_product(context), context.consultant)
      assert {:ok, %{state: :withdrawn}} = Offers.withdraw(sent, context.consultant)
    end

    test "sent offers past their date expire", context do
      {:ok, sent} = Offers.submit(with_product(context), context.consultant)
      Ash.Seed.update!(sent, %{valid_until: Date.add(Mercator.Clock.today(), -1)})
      {:ok, current} = Offers.submit(with_product(context), context.consultant)

      Offers.expire_overdue()

      assert {:ok, %{state: :expired}} = Offers.get(sent.id, context.consultant)
      assert {:ok, %{state: :sent}} = Offers.get(current.id, context.consultant)
    end
  end
end
