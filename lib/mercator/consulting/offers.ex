defmodule Mercator.Consulting.Offers do
  @moduledoc """
  Offers from the back office (guided selling, step 4): creating, editing
  items, submitting, approving (#98) and revising, as the consultant or
  sales manager (`actor`). The policies of `Mercator.Consulting.Offer`
  decide who may do what.

  After every change to items or the overall discount the offer's totals
  are recalculated with `Mercator.Consulting.OfferTotals`.
  """
  require Ash.Query

  alias Mercator.{Catalog, Translated}
  alias Mercator.Catalog.{Configurator, Variant}
  alias Mercator.Consulting.{Offer, OfferItem, OfferTotals}
  alias Mercator.Sales.{BasketPricing, Baskets}

  @loads [:customer, :consultant, :approved_by, :conversation, items: [:product]]

  @doc "Offers for the back office list; `filters` may hold `:state` and `:customer_id`."
  def list(actor, filters \\ %{}, page \\ [limit: 25]) do
    Offer
    |> Ash.Query.for_read(:search, Map.take(filters, [:state, :customer_id]), actor: actor)
    |> Ash.read!(page: page)
  end

  @doc "A customer's offers, newest first (for the sales desk)."
  def for_customer(customer_id, actor) do
    Offer
    |> Ash.Query.for_read(:search, %{customer_id: customer_id}, actor: actor)
    |> Ash.Query.limit(10)
    |> Ash.read!(page: false)
  end

  @doc "An offer with customer, consultant and items."
  def get(id, actor) do
    Offer
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(@loads)
    |> Ash.read_one(actor: actor)
  end

  @doc "A new draft offer for a customer, in the customer's language."
  def create(customer_id, actor, attrs \\ %{}) do
    customer = Ash.get!(Mercator.Accounts.User, customer_id, authorize?: false)

    Offer
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{customer_id: customer.id, locale: to_string(customer.locale || "de")}, attrs),
      actor: actor
    )
    |> Ash.create()
  end

  @doc "A new draft offer from a conversation; visitors must sign in first (#94)."
  def create_for_conversation(%{customer_id: nil}, _actor), do: {:error, :visitor}

  def create_for_conversation(conversation, actor),
    do: create(conversation.customer_id, actor, %{conversation_id: conversation.id})

  @doc "Changes validity, overall discount or note of a draft."
  def update(offer, attrs, actor) do
    with {:ok, offer} <- Ash.update(offer, attrs, action: :update, actor: actor) do
      recalculate(offer)
    end
  end

  @doc """
  Adds a product variant at its price-list price for the quantity; for
  configurable products with the configuration (`selections`).
  """
  def add_product(offer, variant_id, quantity, actor, selections \\ %{}) do
    variant =
      Ash.get!(Variant, variant_id,
        load: [product: [:tax_class, options: :choices]],
        authorize?: false
      )

    with {:ok, attrs} <- price(variant.product, variant, quantity, selections, offer.locale) do
      attrs
      |> Map.merge(%{
        kind: :product,
        quantity: quantity,
        variant_id: variant.id,
        product_id: variant.product.id
      })
      |> create_item(offer, actor)
    end
  end

  @doc "Adds a free-text item (title, description, quantity, unit, unit_net, vat_rate, …)."
  def add_text(offer, attrs, actor) do
    attrs
    |> Map.put(:kind, :text)
    |> Map.put_new(:vat_rate, default_vat_rate())
    |> create_item(offer, actor)
  end

  @doc """
  Takes over the customer's basket at current prices, configured items
  included. Items no longer available are skipped. Returns
  `{:ok, offer, count}`.
  """
  def import_basket(offer, actor) do
    lines =
      {:user, %{id: offer.customer_id}}
      |> Baskets.get()
      |> BasketPricing.calculate()
      |> Map.fetch!(:lines)
      |> Enum.filter(& &1.available?)

    Enum.each(lines, fn %{item: item} ->
      {:ok, _offer} = add_product(offer, item.variant.id, item.quantity, actor, item.selections)
    end)

    with {:ok, offer} <- get(offer.id, actor), do: {:ok, offer, length(lines)}
  end

  @doc """
  Changes an item. When the quantity of a product item changes, the price
  list price is determined again (graduated prices, configurator); a unit
  price the consultant did not change follows it.
  """
  def update_item(item, attrs, actor) do
    attrs = reprice(item, attrs)

    with {:ok, item} <- Ash.update(item, attrs, action: :update, actor: actor) do
      recalculate(item.offer_id)
    end
  end

  @doc "Removes an item from a draft."
  def remove_item(item, actor) do
    with :ok <- Ash.destroy(item, actor: actor), do: recalculate(item.offer_id)
  end

  @doc "Submits a draft: sent, or waiting for a sales manager's approval (#98)."
  def submit(offer, actor), do: transition(offer, :submit, %{}, actor)

  @doc "A sales manager approves; the offer is sent."
  def approve(offer, actor), do: transition(offer, :approve, %{}, actor)

  @doc "A sales manager sends the offer back to the draft, with a reason."
  def reject(offer, note, actor), do: transition(offer, :reject, %{note: note}, actor)

  @doc "Withdraws an offer that is not yet accepted."
  def withdraw(offer, actor), do: transition(offer, :withdraw, %{}, actor)

  @copied [
    :position,
    :kind,
    :number,
    :title,
    :description,
    :selections,
    :quantity,
    :unit,
    :list_unit_net,
    :unit_net,
    :discount_percent,
    :vat_rate,
    :delivery_time,
    :variant_id,
    :product_id
  ]

  @doc """
  Revises a sent or expired offer: a new draft with the same number, the
  next version and copies of the items; the old offer becomes `revised`.
  """
  def revise(offer, actor) do
    offer = Ash.load!(offer, :items, authorize?: false)

    attrs =
      offer
      |> Map.take([:customer_id, :conversation_id, :locale, :discount_percent, :note])
      |> Map.merge(%{
        number: offer.number,
        year: offer.year,
        sequence: offer.sequence,
        version: offer.version + 1,
        previous_offer_id: offer.id,
        valid_until: Enum.max([offer.valid_until, Offer.default_valid_until()], Date),
        items: Enum.map(offer.items, &Map.take(&1, @copied))
      })

    with {:ok, revision} <- Ash.create(Offer, attrs, action: :revision, actor: actor) do
      recalculate(revision)
    end
  end

  @doc "Sent offers past their validity date expire (daily job)."
  def expire_overdue do
    Offer
    |> Ash.Query.filter(state == :sent and valid_until < ^Mercator.Clock.today())
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.update!(&1, %{}, action: :expire, authorize?: false))
  end

  @doc "Stores the totals of an offer (or offer id) and returns it with everything loaded."
  def recalculate(%Offer{id: id}), do: recalculate(id)

  def recalculate(offer_id) do
    offer = Ash.get!(Offer, offer_id, load: [:items], authorize?: false)
    totals = OfferTotals.calculate(offer.items, offer.discount_percent)

    offer
    |> Ash.Changeset.for_update(:set_totals, %{
      net: totals.net,
      vat: totals.vat,
      gross: totals.gross,
      vat_lines: OfferTotals.snapshot_vat_lines(totals.vat_lines)
    })
    |> Ash.update!(authorize?: false)
    |> Ash.load(@loads, authorize?: false)
  end

  @doc "Whether the offer needs a sales manager's approval when a consultant submits it."
  def needs_approval?(offer) do
    Decimal.gt?(
      OfferTotals.max_discount(offer.items, offer.discount_percent),
      Offer.approval_limit()
    )
  end

  defp transition(offer, action, args, actor) do
    with {:ok, offer} <- Ash.update(offer, args, action: action, actor: actor) do
      Ash.load(offer, @loads, authorize?: false)
    end
  end

  defp create_item(attrs, offer, actor) do
    attrs = Map.put_new_lazy(attrs, :position, fn -> next_position(offer.id) end)

    with {:ok, _item} <-
           Ash.create(OfferItem, Map.put(attrs, :offer_id, offer.id), actor: actor) do
      recalculate(offer.id)
    end
  end

  defp next_position(offer_id) do
    OfferItem
    |> Ash.Query.filter(offer_id == ^offer_id)
    |> Ash.Query.sort(position: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> 1
      item -> item.position + 1
    end
  end

  defp price(%{kind: :configurable} = product, _variant, quantity, selections, locale) do
    case Catalog.quote(product, selections, Decimal.to_string(Decimal.new(quantity), :normal)) do
      {:ok, quote} ->
        {:ok,
         %{
           number: quote.config_number,
           title: Translated.t(product.title, locale),
           description: Configurator.describe(product, quote.selections, locale),
           selections: quote.selections,
           unit: :piece,
           list_unit_net: quote.unit_net,
           unit_net: quote.unit_net,
           vat_rate: quote.vat_rate
         }}

      {:error, _errors} ->
        {:error, :no_price}
    end
  end

  defp price(product, variant, quantity, _selections, locale) do
    with {:ok, info} <- Catalog.price_for(%{variant | product: product}, quantity) do
      {:ok,
       %{
         number: variant.number,
         title: Translated.t(product.title, locale),
         description: Translated.t(variant.name, locale),
         unit: variant.unit,
         list_unit_net: info.unit_net,
         unit_net: info.unit_net,
         vat_rate: info.vat_rate
       }}
    end
  end

  defp reprice(%{kind: :product, variant_id: variant_id} = item, %{quantity: quantity} = attrs)
       when not is_nil(variant_id) and not is_nil(quantity) do
    variant =
      Ash.get!(Variant, variant_id,
        load: [product: [:tax_class, options: :choices]],
        authorize?: false
      )

    with false <- Decimal.equal?(Decimal.new(quantity), item.quantity),
         {:ok, %{list_unit_net: list}} <-
           price(variant.product, variant, quantity, item.selections, Translated.default_locale()) do
      attrs = Map.put(attrs, :list_unit_net, list)
      if unchanged_price?(item, attrs), do: Map.put(attrs, :unit_net, list), else: attrs
    else
      _ -> attrs
    end
  end

  defp reprice(_item, attrs), do: attrs

  # the consultant neither changed the unit price before nor now
  defp unchanged_price?(item, attrs) do
    not is_nil(item.list_unit_net) and Decimal.equal?(item.unit_net, item.list_unit_net) and
      (is_nil(attrs[:unit_net]) or Decimal.equal?(Decimal.new(attrs[:unit_net]), item.unit_net))
  end

  defp default_vat_rate do
    Catalog.TaxClass
    |> Ash.Query.sort(position: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> Decimal.new(20)
      tax_class -> tax_class.rate
    end
  end
end
