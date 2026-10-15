defmodule MercatorWeb.Documents do
  @moduledoc """
  PDF documents (#17): the data for `priv/typst/document.typ`, formatted
  and translated here in the document's language, rendered by
  `Mercator.Pdf`.
  """
  use Gettext, backend: MercatorWeb.Gettext
  use MercatorWeb, :verified_routes

  require Ash.Query

  alias Mercator.Accounts.Address
  alias Mercator.Brand
  alias Mercator.Catalog.Unit
  alias Mercator.Consulting.{Desk, Offer, OfferTotals}
  alias Mercator.Countries
  alias MercatorWeb.Format

  @doc """
  The offer as PDF, in the offer's language. The offer needs its items,
  customer and consultant (as from `Mercator.Consulting.Offers.get/2`).
  """
  def offer_pdf(%Offer{} = offer) do
    Gettext.with_locale(MercatorWeb.Gettext, offer.locale, fn ->
      Mercator.Pdf.render("document", offer_data(offer))
    end)
  end

  @doc "The file name of the offer PDF, e.g. `Angebot-BH-A-2026-00012-2.pdf`."
  def offer_filename(%Offer{} = offer) do
    Gettext.with_locale(MercatorWeb.Gettext, offer.locale, fn ->
      "#{gettext("Offer")}-#{String.replace(Offer.display_number(offer), "/", "-")}.pdf"
    end)
  end

  @doc "The customer's address for documents: the default billing address, else the first."
  def billing_address(user_id) do
    Address
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.sort(default_billing: :desc, inserted_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  @doc "An address as lines of text."
  def address_lines(nil), do: []

  def address_lines(address) do
    [
      address.company,
      address.name,
      address.street,
      "#{address.postcode} #{address.city}",
      Countries.name(address.country),
      address.vat_id && "#{gettext("VAT ID")}: #{address.vat_id}"
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  @doc "The data of the offer document (call within the offer's locale, see `offer_pdf/1`)."
  def offer_data(offer) do
    locale = offer.locale
    totals = OfferTotals.calculate(offer.items, offer.discount_percent)
    number = Offer.display_number(offer)
    discounts? = Enum.any?(offer.items, &Decimal.gt?(&1.discount_percent, 0))

    %{
      lang: locale,
      title: gettext("Offer %{number}", number: number),
      brand: brand(),
      recipient: recipient(offer),
      meta:
        [
          [gettext("Offer"), number],
          [gettext("Date"), Format.date(offer.sent_at || offer.inserted_at)],
          [gettext("Valid until"), Format.date(offer.valid_until)],
          offer.consultant && [gettext("Consultant"), Desk.display_name(offer.consultant)]
        ]
        |> Enum.filter(& &1),
      intro: offer.note,
      columns:
        [
          column(gettext("Pos.")),
          column(gettext("Quantity"), "right"),
          column(gettext("Item"), "left", true),
          column(gettext("Unit price"), "right"),
          discounts? && column(gettext("Discount"), "right"),
          column(gettext("Amount"), "right")
        ]
        |> Enum.filter(& &1),
      rows:
        totals.lines
        |> Enum.with_index(1)
        |> Enum.map(fn {line, index} -> offer_row(line, index, discounts?, locale) end),
      sums: offer_sums(offer, totals, locale),
      footer: [
        gettext("Prices in euros. This offer is valid until %{date}.",
          date: Format.date(offer.valid_until)
        ),
        gettext("Our terms and conditions apply: %{url}", url: url(~p"/terms"))
      ]
    }
  end

  defp offer_row(%{item: item} = line, index, discounts?, locale) do
    [
      to_string(index),
      "#{Format.quantity(item.quantity, item.unit, locale)} #{Unit.symbol(item.unit)}",
      %{
        title: item.title,
        details:
          Enum.reject(
            [
              item.number,
              item.description,
              item.delivery_time && gettext("Delivery: %{time}", time: item.delivery_time)
            ],
            &(&1 in [nil, ""])
          )
      },
      Format.money(item.unit_net, locale),
      discounts? && discount(item.discount_percent),
      Format.money(line.goods, locale)
    ]
    |> Enum.reject(&(&1 == false))
  end

  defp discount(percent) do
    if Decimal.gt?(percent, 0), do: "#{Format.percent(percent)} %", else: ""
  end

  defp offer_sums(offer, totals, locale) do
    discount =
      if Decimal.gt?(totals.discount, 0) do
        [
          sum(gettext("Items (net)"), Format.money(totals.goods_net, locale)),
          sum(
            gettext("Discount %{percent} %", percent: Format.percent(offer.discount_percent)),
            "−" <> Format.money(totals.discount, locale)
          )
        ]
      else
        []
      end

    discount ++
      [sum(gettext("Net total"), Format.money(totals.net, locale))] ++
      Enum.map(
        totals.vat_lines,
        &sum(
          gettext("VAT %{rate} %", rate: Format.percent(&1.rate)),
          Format.money(&1.vat, locale)
        )
      ) ++ [sum(gettext("Total"), Format.money(totals.gross, locale), true)]
  end

  defp recipient(offer) do
    case address_lines(billing_address(offer.customer_id)) do
      [] -> [Desk.display_name(offer.customer), to_string(offer.customer.email)]
      lines -> lines
    end
  end

  defp brand do
    %{
      name: Brand.name(),
      lines: Enum.filter([Brand.get(:address), Brand.get(:phone), Brand.get(:email)], & &1)
    }
  end

  defp column(label, align \\ "left", wide \\ false),
    do: %{label: label, align: align, wide: wide}

  defp sum(label, value, strong \\ false), do: %{label: label, value: value, strong: strong}
end
