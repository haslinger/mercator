defmodule Mercator.Sales.OrderEmail do
  @moduledoc """
  The order confirmation email (#70: text and HTML, no PDF), in the
  customer's language.
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
