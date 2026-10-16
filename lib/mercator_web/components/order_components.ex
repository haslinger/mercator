defmodule MercatorWeb.OrderComponents do
  @moduledoc """
  Parts of an order shown both to the customer (`MercatorWeb.OrderLive`) and
  to staff (`MercatorWeb.Admin.OrderShowLive`): items, addresses, totals and
  state labels.
  """
  use MercatorWeb, :html

  import MercatorWeb.AddressComponents, only: [address_lines: 1]

  alias Mercator.{Brand, Translated}
  alias Mercator.Catalog.Unit
  alias Mercator.Sales.Shipping
  alias MercatorWeb.Format

  @address_fields ~w(name company street postcode city country phone vat_id)

  attr :order, :map, required: true, doc: "the order with its items loaded"
  attr :locale, :string, required: true

  def order_items(assigns) do
    ~H"""
    <ul class="divide-y divide-base-300" id="order-items">
      <li
        :for={item <- @order.items}
        class="flex justify-between gap-4 py-2"
        id={"order-item-#{item.id}"}
      >
        <div>
          <p class="font-semibold">
            {Format.quantity(item.quantity, item.unit, @locale)} {Unit.symbol(item.unit)}
            {Translated.t(item.title, @locale)}
          </p>
          <p class="text-sm text-base-content/70">
            {item.number}
            <span :if={item.variant_name}>· {Translated.t(item.variant_name, @locale)}</span>
          </p>
          <p :if={item.configuration} class="text-xs text-base-content/60">
            {Translated.t(item.configuration, @locale)}
          </p>
        </div>
        <span class="font-semibold whitespace-nowrap">{Format.money(item.gross, @locale)}</span>
      </li>
    </ul>
    """
  end

  attr :order, :map, required: true

  @doc "Billing address and delivery (address or pickup) side by side."
  def order_addresses(assigns) do
    ~H"""
    <div class="grid gap-6 sm:grid-cols-2">
      <section class="card bg-base-100 shadow-sm" id="order-billing-address">
        <div class="card-body">
          <h2 class="card-title text-base">{gettext("Billing address")}</h2>
          <.address_lines address={address(@order.billing_address)} />
        </div>
      </section>
      <section class="card bg-base-100 shadow-sm" id="order-delivery">
        <div class="card-body">
          <h2 class="card-title text-base">{Shipping.label(@order.shipping_method)}</h2>
          <%= if @order.shipping_address do %>
            <.address_lines address={address(@order.shipping_address)} />
          <% else %>
            <p>{Brand.get(:address)}</p>
          <% end %>
        </div>
      </section>
    </div>
    """
  end

  attr :order, :map, required: true
  attr :locale, :string, required: true

  def order_totals(assigns) do
    ~H"""
    <aside class="card h-fit bg-base-100 shadow-sm" id="order-totals">
      <div class="card-body gap-2">
        <h2 class="card-title">{gettext("Summary")}</h2>
        <div class="flex justify-between">
          <span>{gettext("Goods")}</span>
          <span>{Format.money(@order.goods_gross, @locale)}</span>
        </div>
        <div class="flex justify-between">
          <span>{gettext("Shipping")}</span>
          <span id="order-shipping">{shipping_text(@order, @locale)}</span>
        </div>
        <div class="flex justify-between border-t border-base-300 pt-2 text-lg font-bold">
          <span>{gettext("Total")}</span>
          <span id="order-total">{Format.money(@order.gross, @locale)}</span>
        </div>
        <div
          :for={line <- @order.vat_lines}
          class="flex justify-between text-sm text-base-content/70"
        >
          <span>{gettext("incl. VAT %{rate} %", rate: Format.percent(Decimal.new(line["rate"])))}</span>
          <span>{Format.money(Decimal.new(line["vat"]), @locale)}</span>
        </div>
        <p :if={@order.shipping_estimate} class="text-xs text-base-content/60">
          {gettext("We confirm the exact freight costs before delivery.")}
        </p>
      </div>
    </aside>
    """
  end

  attr :state, :atom, required: true
  attr :shipping_method, :atom, default: nil, doc: "pickup orders say \"ready for pickup\""
  attr :id, :string, default: nil
  attr :class, :string, default: nil

  def state_badge(assigns) do
    ~H"""
    <span class={["badge", state_class(@state), @class]} id={@id}>
      {state_label(@state, @shipping_method)}
    </span>
    """
  end

  @doc """
  The translated name of an order state. For pickup orders the state
  `:shipped` means "ready for pickup" (#75).
  """
  def state_label(state, shipping_method \\ nil)
  def state_label(:shipped, :pickup), do: pgettext("order state", "Ready for pickup")
  def state_label(state, _shipping_method), do: state_label_text(state)

  defp state_label_text(:placed), do: pgettext("order state", "Placed")
  defp state_label_text(:confirmed), do: pgettext("order state", "Confirmed")
  defp state_label_text(:paid), do: pgettext("order state", "Paid")
  defp state_label_text(:shipped), do: pgettext("order state", "Shipped")
  defp state_label_text(:completed), do: pgettext("order state", "Completed")
  defp state_label_text(:cancelled), do: pgettext("order state", "Cancelled")

  @doc "All order states in their usual order."
  def states, do: [:placed, :confirmed, :paid, :shipped, :completed, :cancelled]

  attr :status, :atom, required: true
  attr :id, :string, default: nil

  @doc "The status of an online payment attempt (phase 7)."
  def payment_status_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm", payment_status_class(@status)]} id={@id}>
      {payment_status_label(@status)}
    </span>
    """
  end

  @doc "The translated name of an online payment status."
  def payment_status_label(:open), do: pgettext("payment status", "Open")
  def payment_status_label(:pending), do: pgettext("payment status", "Processing")
  def payment_status_label(:paid), do: pgettext("payment status", "Paid")
  def payment_status_label(:failed), do: pgettext("payment status", "Failed")
  def payment_status_label(:canceled), do: pgettext("payment status", "Cancelled")
  def payment_status_label(:expired), do: pgettext("payment status", "Expired")
  def payment_status_label(:refunded), do: pgettext("payment status", "Refunded")

  defp payment_status_class(:paid), do: "badge-success"
  defp payment_status_class(:refunded), do: "badge-warning"

  defp payment_status_class(status) when status in [:open, :pending],
    do: "badge-info badge-outline"

  defp payment_status_class(_not_paid), do: "badge-error badge-outline"

  defp state_class(:placed), do: "badge-primary"
  defp state_class(:cancelled), do: "badge-error badge-outline"
  defp state_class(:completed), do: "badge-success badge-outline"
  defp state_class(_state), do: "badge-info badge-outline"

  # order snapshots store addresses with string keys
  defp address(snapshot) do
    Map.new(@address_fields, &{String.to_existing_atom(&1), snapshot[&1]})
  end

  defp shipping_text(%{shipping_gross: gross, shipping_estimate: estimate?}, locale) do
    cond do
      Decimal.equal?(gross, 0) -> gettext("free")
      estimate? -> gettext("from %{amount}", amount: Format.money(gross, locale))
      true -> Format.money(gross, locale)
    end
  end
end
