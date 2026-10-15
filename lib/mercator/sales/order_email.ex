defmodule Mercator.Sales.OrderEmail do
  @moduledoc """
  Emails to the customer about an order, in the customer's language (text
  and HTML; the PDF is attached by the worker): the order confirmation (#70) and state changes by staff
  (#74).
  """

  use Gettext, backend: MercatorWeb.Gettext
  use MercatorWeb, :verified_routes

  import Swoosh.Email

  alias Mercator.{Brand, Countries, Translated}
  alias Mercator.Catalog.Unit
  alias Mercator.Sales.{Payment, Shipping}
  alias MercatorWeb.Format

  @doc "Builds the confirmation email of an order (items loaded)."
  def confirmation(order) do
    Gettext.with_locale(MercatorWeb.Gettext, order.locale, fn ->
      lines = lines(order)

      new()
      |> from(Mercator.Mailer.default_from())
      |> to(order.email)
      |> subject(
        gettext("Your order %{number} at %{shop}", number: order.number, shop: Brand.name())
      )
      |> text_body(Enum.join(lines, "\n"))
      |> html_body(html(lines))
    end)
  end

  @doc """
  Builds the email about a state change (`:confirmed`, `:paid`, `:shipped`
  or `:cancelled`); `note` is the reason of a cancellation. With the order's
  `online_payments` loaded, a cancellation names the online payment that
  will be refunded.
  """
  def status_change(order, state, note \\ nil) do
    Gettext.with_locale(MercatorWeb.Gettext, order.locale, fn ->
      lines =
        status_lines(order, state, note) ++
          [
            "",
            gettext("You can see your order at any time in your account:"),
            url(~p"/account/orders/#{order.number}"),
            "",
            Brand.name()
          ]

      new()
      |> from(Mercator.Mailer.default_from())
      |> to(order.email)
      |> subject(status_subject(order, state))
      |> text_body(Enum.join(lines, "\n"))
      |> html_body(html(lines))
    end)
  end

  defp status_subject(order, :confirmed),
    do: gettext("Your order %{number} is confirmed", number: order.number)

  defp status_subject(order, :paid),
    do: gettext("Payment received for your order %{number}", number: order.number)

  defp status_subject(%{shipping_method: :pickup} = order, :shipped),
    do: gettext("Your order %{number} is ready for pickup", number: order.number)

  defp status_subject(order, :shipped),
    do: gettext("Your order %{number} is on its way", number: order.number)

  defp status_subject(order, :cancelled),
    do: gettext("Your order %{number} has been cancelled", number: order.number)

  defp status_lines(order, :confirmed, _note) do
    [
      gettext("We have checked your order %{number} and confirm it.", number: order.number),
      "",
      "#{Shipping.label(order.shipping_method)}: #{shipping(order, order.locale)}",
      "#{gettext("Total")}: #{Format.money(order.gross, order.locale)}",
      "",
      "#{gettext("Payment")}: #{Payment.label(order.payment_method)}"
    ] ++ Payment.instructions(order)
  end

  # also after shipping or pickup, so nothing about what comes next
  defp status_lines(order, :paid, _note) do
    [
      gettext("We have received your payment of %{amount} for order %{number}. Thank you!",
        amount: Format.money(order.gross, order.locale),
        number: order.number
      )
    ]
  end

  defp status_lines(%{shipping_method: :pickup} = order, :shipped, _note) do
    [
      gettext("Your order %{number} is ready for pickup.", number: order.number),
      "",
      delivery(order)
    ] ++ if(order.payment_method == :on_pickup, do: Payment.instructions(order), else: [])
  end

  defp status_lines(order, :shipped, _note) do
    [
      gettext("Your order %{number} has been shipped.", number: order.number),
      "",
      delivery(order)
    ]
  end

  defp status_lines(order, :cancelled, note) do
    [gettext("We have cancelled your order %{number}.", number: order.number)] ++
      if(note, do: ["", "#{gettext("Reason")}: #{note}"], else: []) ++
      ["", refund_line(order)]
  end

  # paid online (refunded or not yet: the email may go out before the refund, #130)
  defp refund_line(%{online_payments: payments} = order) when is_list(payments) do
    case Enum.find(payments, &(&1.status in [:paid, :refunded])) do
      nil ->
        refund_line(%{order | online_payments: nil})

      payment ->
        gettext("We will refund your online payment of %{amount} to the same payment method.",
          amount: Format.money(payment.amount, order.locale)
        )
    end
  end

  defp refund_line(_order), do: gettext("If you have already paid, we will refund the amount.")

  defp lines(order) do
    locale = order.locale

    [
      gettext("Thank you for your order!"),
      "",
      gettext("Order number: %{number}", number: order.number),
      ""
    ] ++
      Enum.map(order.items, &item_line(&1, locale)) ++
      [
        "",
        "#{Shipping.label(order.shipping_method)}: #{shipping(order, locale)}",
        "#{gettext("Total")}: #{Format.money(order.gross, locale)}"
      ] ++
      Enum.map(order.vat_lines, fn %{"rate" => rate, "vat" => vat} ->
        gettext("incl. VAT %{rate} %: %{amount}",
          rate: Format.percent(Decimal.new(rate)),
          amount: Format.money(Decimal.new(vat), locale)
        )
      end) ++
      ["", "#{gettext("Payment")}: #{Payment.label(order.payment_method)}"] ++
      Payment.instructions(order) ++
      ["", delivery(order)] ++
      if(order.note, do: ["", "#{gettext("Your note")}: #{order.note}"], else: []) ++
      [
        "",
        gettext("You can see your order at any time in your account:"),
        url(~p"/account/orders/#{order.number}"),
        "",
        Brand.name()
      ]
  end

  defp item_line(item, locale) do
    title =
      [Translated.t(item.title, locale), Translated.t(item.variant_name, locale)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    configuration =
      case Translated.t(item.configuration, locale) do
        nil -> ""
        text -> " (#{text})"
      end

    "#{Format.quantity(item.quantity, item.unit, locale)} #{Unit.symbol(item.unit)} #{title}#{configuration} [#{item.number}]: #{Format.money(item.gross, locale)}"
  end

  defp shipping(order, locale) do
    amount = Format.money(order.shipping_gross, locale)

    cond do
      Decimal.equal?(order.shipping_gross, 0) -> gettext("free")
      order.shipping_estimate -> gettext("from %{amount}", amount: amount)
      true -> amount
    end
  end

  defp delivery(%{shipping_method: :pickup}) do
    case Brand.get(:address) do
      nil -> gettext("Pickup")
      address -> gettext("Pickup at %{address}", address: address)
    end
  end

  defp delivery(%{shipping_address: address}) do
    gettext("Delivery to: %{address}", address: address_text(address))
  end

  defp address_text(address) do
    [
      address["name"],
      address["company"],
      address["street"],
      "#{address["postcode"]} #{address["city"]}",
      Countries.name(address["country"])
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
  end

  defp html(lines) do
    paragraphs =
      lines
      |> Enum.chunk_by(&(&1 == ""))
      |> Enum.reject(&(&1 == [""] or Enum.all?(&1, fn line -> line == "" end)))
      |> Enum.map_join("\n", fn chunk ->
        "<p>" <> Enum.map_join(chunk, "<br>", &escape/1) <> "</p>"
      end)

    ~s(<div style="font-family: sans-serif; line-height: 1.5">#{paragraphs}</div>)
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
