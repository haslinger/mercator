defmodule MercatorWeb.OfferPrintHTML do
  @moduledoc "The printable offer document (`MercatorWeb.OfferPrintController`)."
  use MercatorWeb, :html

  import MercatorWeb.AddressesLive, only: [address_lines: 1]

  alias Mercator.Brand
  alias Mercator.Catalog.Unit
  alias Mercator.Consulting.{Desk, Offer}
  alias MercatorWeb.Format

  attr :offer, :map, required: true
  attr :address, :map, default: nil
  attr :totals, :map, required: true, doc: "`Mercator.Consulting.OfferTotals.calculate/2`"
  attr :locale, :string, required: true

  def offer(assigns) do
    ~H"""
    <div class="mx-auto my-6 flex max-w-3xl justify-end gap-2 px-4 print:hidden">
      <button type="button" class="btn btn-primary" data-print id="print-offer">
        <.icon name="hero-printer" class="size-5" /> {gettext("Print")}
      </button>
    </div>

    <article
      class="mx-auto mb-10 max-w-3xl bg-base-100 p-10 text-sm shadow print:m-0 print:max-w-none print:p-0 print:shadow-none"
      id="offer-document"
    >
      <header class="flex items-start justify-between gap-6 border-b border-base-300 pb-6">
        <img src={~p"/brand/logo"} alt={Brand.name()} class="h-16 w-auto" />
        <div class="text-right text-xs leading-relaxed text-base-content/80">
          <p class="font-semibold text-base-content">{Brand.name()}</p>
          <p :if={Brand.get(:address)}>{Brand.get(:address)}</p>
          <p :if={Brand.get(:phone)}>{Brand.get(:phone)}</p>
          <p :if={Brand.get(:email)}>{Brand.get(:email)}</p>
        </div>
      </header>

      <section class="mt-8 flex flex-wrap justify-between gap-6">
        <div id="offer-customer">
          <%= if @address do %>
            <.address_lines address={@address} />
          <% else %>
            <p>{Desk.display_name(@offer.customer)}</p>
            <p>{@offer.customer.email}</p>
          <% end %>
        </div>
        <dl class="grid grid-cols-[auto_auto] gap-x-4 gap-y-1 text-right">
          <dt class="text-base-content/70">{gettext("Offer")}</dt>
          <dd class="font-semibold">{Offer.display_number(@offer)}</dd>
          <dt class="text-base-content/70">{gettext("Date")}</dt>
          <dd>{Format.date(@offer.sent_at || @offer.inserted_at)}</dd>
          <dt class="text-base-content/70">{gettext("Valid until")}</dt>
          <dd>{Format.date(@offer.valid_until)}</dd>
          <dt :if={@offer.consultant} class="text-base-content/70">{gettext("Consultant")}</dt>
          <dd :if={@offer.consultant}>{Desk.display_name(@offer.consultant)}</dd>
        </dl>
      </section>

      <h1 class="mt-10 text-2xl font-bold">
        {gettext("Offer %{number}", number: Offer.display_number(@offer))}
      </h1>
      <p :if={@offer.note} class="mt-3 whitespace-pre-line" id="offer-note">{@offer.note}</p>

      <table class="mt-6 w-full border-collapse" id="offer-lines">
        <thead>
          <tr class="border-b-2 border-base-300 text-left text-xs text-base-content/70">
            <th class="py-2 pr-2">{gettext("Pos.")}</th>
            <th class="py-2 pr-2">{gettext("Quantity")}</th>
            <th class="py-2 pr-2">{gettext("Item")}</th>
            <th class="py-2 pr-2 text-right">{gettext("Unit price")}</th>
            <th class="py-2 pr-2 text-right">{gettext("Discount")}</th>
            <th class="py-2 text-right">{gettext("Amount")}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={{line, index} <- Enum.with_index(@totals.lines, 1)}
            class="border-b border-base-200 align-top break-inside-avoid"
          >
            <td class="py-2 pr-2">{index}</td>
            <td class="py-2 pr-2 whitespace-nowrap">
              {Format.quantity(line.item.quantity, line.item.unit, @locale)} {Unit.symbol(
                line.item.unit
              )}
            </td>
            <td class="py-2 pr-2">
              <p class="font-semibold">{line.item.title}</p>
              <p :if={line.item.number} class="text-xs text-base-content/70">{line.item.number}</p>
              <p :if={line.item.description} class="text-xs text-base-content/70">
                {line.item.description}
              </p>
              <p :if={line.item.delivery_time} class="text-xs text-base-content/70">
                {gettext("Delivery: %{time}", time: line.item.delivery_time)}
              </p>
            </td>
            <td class="py-2 pr-2 text-right whitespace-nowrap">
              {Format.money(line.item.unit_net, @locale)}
            </td>
            <td class="py-2 pr-2 text-right whitespace-nowrap">
              {if Decimal.gt?(line.item.discount_percent, 0),
                do: "#{Format.percent(line.item.discount_percent)} %"}
            </td>
            <td class="py-2 text-right whitespace-nowrap">{Format.money(line.goods, @locale)}</td>
          </tr>
        </tbody>
      </table>

      <div class="mt-4 ml-auto w-72 break-inside-avoid">
        <.offer_sums offer={@offer} totals={@totals} locale={@locale} />
      </div>

      <footer class="mt-10 border-t border-base-300 pt-4 text-xs text-base-content/70">
        <p>
          {gettext("Prices in euros. This offer is valid until %{date}.",
            date: Format.date(@offer.valid_until)
          )}
          {gettext("Our terms and conditions apply: %{url}", url: url(~p"/terms"))}
        </p>
      </footer>
    </article>
    """
  end

  attr :offer, :map, required: true
  attr :totals, :map, required: true
  attr :locale, :string, required: true

  defp offer_sums(assigns) do
    ~H"""
    <dl class="space-y-1" id="offer-totals">
      <div :if={Decimal.gt?(@totals.discount, 0)} class="flex justify-between">
        <dt>{gettext("Items (net)")}</dt>
        <dd>{Format.money(@totals.goods_net, @locale)}</dd>
      </div>
      <div :if={Decimal.gt?(@totals.discount, 0)} class="flex justify-between">
        <dt>{gettext("Discount %{percent} %", percent: Format.percent(@offer.discount_percent))}</dt>
        <dd>−{Format.money(@totals.discount, @locale)}</dd>
      </div>
      <div class="flex justify-between">
        <dt>{gettext("Net total")}</dt>
        <dd>{Format.money(@totals.net, @locale)}</dd>
      </div>
      <div :for={line <- @totals.vat_lines} class="flex justify-between">
        <dt>{gettext("VAT %{rate} %", rate: Format.percent(line.rate))}</dt>
        <dd>{Format.money(line.vat, @locale)}</dd>
      </div>
      <div class="flex justify-between border-t-2 border-base-300 pt-1 text-base font-bold">
        <dt>{gettext("Total")}</dt>
        <dd id="offer-gross">{Format.money(@totals.gross, @locale)}</dd>
      </div>
    </dl>
    """
  end
end
