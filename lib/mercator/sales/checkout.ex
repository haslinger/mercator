defmodule Mercator.Sales.Checkout do
  @moduledoc """
  Checkout of a signed-in customer's basket (checkout-design.md, section 5;
  #66: signed-in customers only).

  `prepare/2` resolves the customer's choices (addresses, shipping and
  payment method) against what is possible and calculates the totals, for
  display. `place/2` checks everything again and, in one transaction,
  reduces the stock, creates the order snapshot and empties the basket. The
  confirmation email is sent by an Oban job.
  """

  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.{Accounts, Catalog, Countries, Sales, Translated}
  alias Mercator.Catalog.{Configurator, Variant}
  alias Mercator.Sales.{BasketPricing, Baskets, OrderTotals, Payment, Shipping}
  alias Mercator.Sales.Workers.SendOrderConfirmation

  require Ash.Query

  @address_fields ~w(name company street postcode city country phone vat_id)a

  @doc """
  The checkout state for a user and the form params (string keys
  `billing_address_id`, `shipping_address_id`, `shipping_method`,
  `payment_method`). Invalid or missing choices fall back to defaults.
  """
  def prepare(user, params \\ %{}) do
    pricing = {:user, user} |> Baskets.get() |> BasketPricing.calculate()
    lines = Enum.filter(pricing.lines, & &1.available?)
    addresses = Accounts.list_my_addresses!(actor: user)
    delivery_addresses = Enum.filter(addresses, &(&1.country in Countries.delivery()))

    billing = pick(addresses, params["billing_address_id"], & &1.default_billing)

    shipping_methods = Shipping.methods_for(Enum.map(lines, & &1.product))
    shipping_method = pick_value(shipping_methods, params["shipping_method"])

    delivery_address =
      pick(delivery_addresses, params["shipping_address_id"], & &1.default_shipping)

    shipping_address = if shipping_method != :pickup, do: delivery_address

    shipping_options =
      Enum.map(shipping_methods, &{&1, shipping_cost(&1, delivery_address, pricing)})

    shipping_cost = shipping_cost(shipping_method, shipping_address, pricing)
    payment_methods = Payment.methods_for(user, shipping_method)

    %{
      pricing: pricing,
      unavailable?: length(lines) < length(pricing.lines),
      addresses: addresses,
      delivery_addresses: delivery_addresses,
      billing_address: billing,
      shipping_address: shipping_address,
      shipping_methods: shipping_methods,
      shipping_options: shipping_options,
      shipping_method: shipping_method,
      shipping_cost: shipping_cost,
      payment_methods: payment_methods,
      payment_method: pick_value(payment_methods, params["payment_method"]),
      totals:
        OrderTotals.calculate(pricing, (shipping_cost && shipping_cost.gross) || Decimal.new(0)),
      gtc: Sales.current_gtc!()
    }
  end

  @doc """
  What still prevents ordering, as a list of `{field, message}`; empty when
  the order can be placed. `gtc_accepted?` is the customer's checkbox.
  """
  def problems(checkout, gtc_accepted?) do
    [
      {:basket, checkout.pricing.lines == [], gettext("Your basket is empty.")},
      {:basket, checkout.unavailable?,
       gettext("Please remove the items that are no longer available.")},
      {:billing_address, is_nil(checkout.billing_address),
       gettext("Please add a billing address.")},
      {:shipping_address,
       checkout.shipping_method != :pickup and is_nil(checkout.shipping_address),
       gettext("Please add a delivery address in a country we deliver to.")},
      {:shipping_method, shipping_method_problem?(checkout),
       gettext("Please choose a shipping method.")},
      {:payment_method, is_nil(checkout.payment_method),
       gettext("Please choose a payment method.")},
      {:gtc, is_nil(checkout.gtc), gettext("Ordering is not possible at the moment.")},
      {:gtc, not gtc_accepted?, gettext("Please accept the terms and conditions.")}
    ]
    |> Enum.filter(fn {_field, problem?, _message} -> problem? end)
    |> Enum.map(fn {field, _problem?, message} -> {field, message} end)
  end

  # Without a delivery address there are no costs yet; that is reported as a
  # missing address, not as a missing shipping method.
  defp shipping_method_problem?(%{shipping_method: nil}), do: true

  defp shipping_method_problem?(%{shipping_method: method, shipping_address: nil})
       when method != :pickup,
       do: false

  defp shipping_method_problem?(checkout), do: is_nil(checkout.shipping_cost)

  @doc """
  Places the order. Params as for `prepare/2`, plus `"gtc" => "true"` and an
  optional `"note"`. Returns `{:ok, order}` or `{:error, [{field, message}]}`.
  """
  def place(user, params) do
    checkout = prepare(user, params)

    case problems(checkout, params["gtc"] == "true") do
      [] -> create(user, checkout, params["note"])
      problems -> {:error, problems}
    end
  end

  defp create(user, checkout, note) do
    lines = Enum.filter(checkout.pricing.lines, & &1.available?)

    # notifications are sent after the commit
    result =
      Mercator.Repo.transaction(fn ->
        with {:ok, stock_notifications} <- reduce_stock(lines),
             {:ok, order, order_notifications} <-
               Ash.create(Sales.Order, order_params(user, checkout, lines, note),
                 action: :place,
                 actor: user,
                 return_notifications?: true
               ) do
          basket_notifications = Baskets.clear({:user, user})
          {order, stock_notifications ++ order_notifications ++ basket_notifications}
        else
          {:error, reason} -> Mercator.Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, {order, notifications}} ->
        Ash.Notifier.notify(notifications)
        %{order_id: order.id} |> SendOrderConfirmation.new() |> Oban.insert!()
        {:ok, order}

      {:error, {:stock, message}} ->
        {:error, [{:basket, message}]}

      {:error, _error} ->
        {:error, [{:basket, gettext("The order could not be placed. Please try again.")}]}
    end
  end

  defp order_params(user, checkout, lines, note) do
    totals = checkout.totals

    %{
      email: to_string(user.email),
      locale: to_string(user.locale),
      billing_address: snapshot(checkout.billing_address),
      shipping_address: checkout.shipping_address && snapshot(checkout.shipping_address),
      shipping_method: checkout.shipping_method,
      payment_method: checkout.payment_method,
      shipping_gross: checkout.shipping_cost.gross,
      shipping_estimate: checkout.shipping_cost.estimate?,
      goods_gross: totals.goods_gross,
      net: totals.net,
      vat: totals.vat,
      gross: totals.gross,
      vat_lines:
        Enum.map(
          totals.vat_lines,
          &Map.new(&1, fn {key, value} -> {to_string(key), Decimal.to_string(value)} end)
        ),
      gtc_version: checkout.gtc.version,
      gtc_accepted_at: DateTime.utc_now(),
      note: blank_to_nil(note),
      items: lines |> Enum.with_index(1) |> Enum.map(&item/1)
    }
  end

  defp item({line, position}) do
    %{product: product, variant: variant, item: item} = line

    %{
      position: position,
      number: item.config_number || variant.number,
      title: product.title,
      variant_name: variant.name,
      configuration: configuration(product, item.selections),
      unit: if(product.kind == :configurable, do: :piece, else: variant.unit),
      quantity: item.quantity,
      unit_net: line.unit_net,
      vat_rate: line.vat_rate,
      net: line.net,
      vat: line.vat,
      gross: line.gross,
      variant_id: variant.id,
      product_id: product.id
    }
  end

  defp configuration(_product, selections) when map_size(selections) == 0, do: nil

  defp configuration(product, selections),
    do: Map.new(Translated.locales(), &{&1, Configurator.describe(product, selections, &1)})

  defp snapshot(address),
    do: address |> Map.take(@address_fields) |> Map.new(fn {k, v} -> {to_string(k), v} end)

  # Stock is tracked for variants with a stock value (#54); others are made to order.
  defp reduce_stock(lines) do
    lines
    |> Enum.group_by(& &1.variant.id, & &1.item.quantity)
    |> Enum.reduce_while({:ok, []}, fn {variant_id, quantities}, {:ok, notifications} ->
      quantity = Enum.reduce(quantities, &Decimal.add/2)

      case reduce_variant_stock(variant_id, quantity) do
        {:ok, more} -> {:cont, {:ok, more ++ notifications}}
        error -> {:halt, error}
      end
    end)
  end

  defp reduce_variant_stock(variant_id, quantity) do
    variant =
      Variant
      |> Ash.Query.filter(id == ^variant_id)
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read_one!(authorize?: false)

    cond do
      is_nil(variant.stock) ->
        {:ok, []}

      Decimal.compare(variant.stock, quantity) == :lt ->
        {:error,
         {:stock,
          gettext("Only %{stock} of %{number} are in stock.",
            stock: Decimal.to_string(Decimal.normalize(variant.stock), :normal),
            number: variant.number
          )}}

      true ->
        {_variant, notifications} =
          Catalog.update_variant!(variant, %{stock: Decimal.sub(variant.stock, quantity)},
            authorize?: false,
            return_notifications?: true
          )

        {:ok, notifications}
    end
  end

  defp shipping_cost(nil, _address, _pricing), do: nil

  defp shipping_cost(:pickup, _address, pricing),
    do: ok_or_nil(Shipping.cost(:pickup, nil, pricing.gross))

  defp shipping_cost(_method, nil, _pricing), do: nil

  defp shipping_cost(method, address, pricing),
    do: ok_or_nil(Shipping.cost(method, address.country, pricing.gross))

  defp ok_or_nil({:ok, cost}), do: cost
  defp ok_or_nil(_error), do: nil

  # the record with the given id, else the default, else the first one
  defp pick(records, id, default?) do
    Enum.find(records, &(&1.id == id)) || Enum.find(records, default?) || List.first(records)
  end

  defp pick_value(values, value) do
    Enum.find(values, &(to_string(&1) == value)) || List.first(values)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(text) do
    case String.trim(text) do
      "" -> nil
      text -> text
    end
  end
end
