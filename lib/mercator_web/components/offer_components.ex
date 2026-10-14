defmodule MercatorWeb.OfferComponents do
  @moduledoc """
  Parts of an offer shown to staff (`MercatorWeb.Admin.OfferEditLive`) and,
  later, to the customer: state labels, items and totals.
  """
  use MercatorWeb, :html

  alias Mercator.Catalog.Unit
  alias Mercator.Consulting.OfferTotals
  alias MercatorWeb.Format

  @states [:draft, :pending_approval, :sent, :accepted, :expired, :withdrawn, :revised]

  @doc "All offer states, in lifecycle order."
  def states, do: @states

  @doc "The label of an offer state."
  def state_label(:draft), do: gettext("Draft")
  def state_label(:pending_approval), do: gettext("Awaiting approval")
  def state_label(:sent), do: pgettext("offer", "Sent")
  def state_label(:accepted), do: gettext("Accepted")
  def state_label(:expired), do: gettext("Expired")
  def state_label(:withdrawn), do: gettext("Withdrawn")
  def state_label(:revised), do: gettext("Revised")

  attr :state, :atom, required: true
  attr :id, :string, default: nil

  def state_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm whitespace-nowrap", badge_class(@state)]} id={@id}>
      {state_label(@state)}
    </span>
    """
  end

  defp badge_class(:draft), do: "badge-ghost"
  defp badge_class(:pending_approval), do: "badge-warning"
  defp badge_class(:sent), do: "badge-info"
  defp badge_class(:accepted), do: "badge-success"
  defp badge_class(_state), do: "badge-neutral"

  attr :offer, :map, required: true, doc: "the offer with its items loaded"
  attr :locale, :string, required: true

  @doc "Read-only list of the items."
  def offer_items(assigns) do
    ~H"""
    <ul class="divide-y divide-base-300" id="offer-items">
      <li
        :for={item <- @offer.items}
        class="flex justify-between gap-4 py-2"
        id={"offer-item-#{item.id}"}
      >
        <div class="min-w-0">
          <p class="font-semibold">
            {Format.quantity(item.quantity, item.unit, @locale)} {Unit.symbol(item.unit)} {item.title}
          </p>
          <p :if={item.number || item.description} class="text-sm text-base-content/70">
            {[item.number, item.description] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")}
          </p>
          <p class="text-xs text-base-content/60">
            {Format.money(item.unit_net, @locale)} {Format.per_unit(item.unit)}
            <span :if={Decimal.gt?(item.discount_percent, 0)}>
              · {gettext("less %{percent} %", percent: Format.percent(item.discount_percent))}
            </span>
            <span :if={item.delivery_time}>
              · {gettext("Delivery: %{time}", time: item.delivery_time)}
            </span>
          </p>
        </div>
        <span class="font-semibold whitespace-nowrap">
          {Format.money(OfferTotals.item_net(item), @locale)}
        </span>
      </li>
    </ul>
    """
  end

  attr :offer, :map, required: true, doc: "the offer with its items loaded"
  attr :locale, :string, required: true

  @doc "Net amounts, overall discount, VAT per rate and the total."
  def offer_totals(assigns) do
    assigns =
      assign(
        assigns,
        :totals,
        OfferTotals.calculate(assigns.offer.items, assigns.offer.discount_percent)
      )

    ~H"""
    <dl class="space-y-1 text-sm" id="offer-totals">
      <div :if={Decimal.gt?(@totals.discount, 0)} class="flex justify-between">
        <dt>{gettext("Items (net)")}</dt>
        <dd>{Format.money(@totals.goods_net, @locale)}</dd>
      </div>
      <div :if={Decimal.gt?(@totals.discount, 0)} class="flex justify-between" id="offer-discount">
        <dt>
          {gettext("Discount %{percent} %", percent: Format.percent(@offer.discount_percent))}
        </dt>
        <dd>−{Format.money(@totals.discount, @locale)}</dd>
      </div>
      <div class="flex justify-between">
        <dt>{gettext("Net total")}</dt>
        <dd>{Format.money(@totals.net, @locale)}</dd>
      </div>
      <div :for={line <- @totals.vat_lines} class="flex justify-between text-base-content/70">
        <dt>{gettext("VAT %{rate} %", rate: Format.percent(line.rate))}</dt>
        <dd>{Format.money(line.vat, @locale)}</dd>
      </div>
      <div class="flex justify-between border-t border-base-300 pt-1 text-base font-bold">
        <dt>{gettext("Total")}</dt>
        <dd id="offer-gross">{Format.money(@totals.gross, @locale)}</dd>
      </div>
    </dl>
    """
  end
end
