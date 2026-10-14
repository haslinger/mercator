defmodule MercatorWeb.OrderLive do
  @moduledoc """
  An order of the signed-in customer (`/account/orders/:number`): items,
  totals, payment instructions and addresses. Also the confirmation page
  after checkout.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.AddressesLive, only: [address_lines: 1]

  alias Mercator.{Brand, Sales, Translated}
  alias Mercator.Catalog.Unit
  alias Mercator.Sales.{Payment, Shipping}
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @address_fields ~w(name company street postcode city country phone vat_id)

  @impl true
  def mount(%{"number" => number}, _session, socket) do
    case Sales.get_order_by_number(number, actor: socket.assigns.current_user, load: [:items]) do
      {:ok, order} ->
        {:ok, socket |> assign(:page_title, order.number) |> assign(:order, order)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Order not found."))
         |> push_navigate(to: ~p"/account/orders")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav_categories={@nav_categories}
      basket_count={@basket_count}
    >
      <.link navigate={~p"/account/orders"} class="link link-hover text-sm w-fit" id="back-to-orders">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("My orders")}
      </.link>
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h1 class="text-3xl font-bold" id="order-number">
          {gettext("Order %{number}", number: @order.number)}
        </h1>
        <span class="badge badge-primary" id="order-state">{state_label(@order.state)}</span>
      </div>
      <p class="text-sm text-base-content/70">
        {gettext("Ordered on %{date}", date: Calendar.strftime(@order.inserted_at, "%d.%m.%Y"))}
      </p>

      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <div class="space-y-6">
          <section class="card bg-base-100 shadow-sm" id="order-payment">
            <div class="card-body gap-1">
              <h2 class="card-title">{gettext("Payment")}: {Payment.label(@order.payment_method)}</h2>
              <p :for={line <- Payment.instructions(@order)} class="first:mb-1">{line}</p>
            </div>
          </section>

          <section class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h2 class="card-title">{gettext("Items")}</h2>
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
              <p :if={@order.note} class="text-sm" id="order-note">
                <span class="font-semibold">{gettext("Your note")}:</span> {@order.note}
              </p>
            </div>
          </section>

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
        </div>

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
      </div>
    </Layouts.app>
    """
  end

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

  @doc "The translated name of an order state."
  def state_label(:placed), do: pgettext("order state", "Placed")
  def state_label(:confirmed), do: pgettext("order state", "Confirmed")
  def state_label(:paid), do: pgettext("order state", "Paid")
  def state_label(:shipped), do: pgettext("order state", "Shipped")
  def state_label(:completed), do: pgettext("order state", "Completed")
  def state_label(:cancelled), do: pgettext("order state", "Cancelled")
end
