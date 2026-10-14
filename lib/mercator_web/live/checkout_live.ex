defmodule MercatorWeb.CheckoutLive do
  @moduledoc """
  The checkout (`/checkout`, checkout-design.md section 5): addresses, shipping
  and payment method, review with totals, GTC and "Zahlungspflichtig
  bestellen" on one page. Signed-in customers only (#66).
  """
  use MercatorWeb, :live_view

  import MercatorWeb.AddressesLive, only: [address_lines: 1]

  alias Mercator.Brand
  alias Mercator.Catalog.{Configurator, Unit}
  alias Mercator.Sales.{Checkout, Payment, Shipping}
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Checkout"))
      |> assign(:params, %{})
      |> assign(:problems, [])
      |> assign(:submitted?, false)
      |> load()

    if socket.assigns.checkout.pricing.lines == [] do
      {:ok, push_navigate(socket, to: ~p"/basket")}
    else
      {:ok, socket}
    end
  end

  defp load(socket) do
    checkout = Checkout.prepare(socket.assigns.current_user, socket.assigns.params)

    socket
    |> assign(:checkout, checkout)
    |> assign(:basket_count, length(checkout.pricing.lines))
    |> assign(:problems, problems(checkout, socket.assigns))
  end

  # problems are shown once the customer has tried to order
  defp problems(_checkout, %{submitted?: false}), do: []

  defp problems(checkout, %{params: params}),
    do: Checkout.problems(checkout, params["gtc"] == "true")

  @impl true
  def handle_event("change", %{"checkout" => params}, socket) do
    {:noreply, socket |> assign(:params, params) |> load()}
  end

  def handle_event("place", %{"checkout" => params}, socket) do
    socket = assign(socket, params: params, submitted?: true)

    case Checkout.place(socket.assigns.current_user, params) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Thank you for your order!"))
         |> push_navigate(to: ~p"/account/orders/#{order.number}")}

      {:error, _problems} ->
        {:noreply, load(socket)}
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
      <h1 class="text-3xl font-bold">{gettext("Checkout")}</h1>

      <.form
        for={%{}}
        as={:checkout}
        id="checkout-form"
        phx-change="change"
        phx-submit="place"
        class="grid gap-6 lg:grid-cols-[1fr_22rem]"
      >
        <div class="space-y-6">
          <.step number={1} title={gettext("Billing address")} id="billing-step">
            <.address_choice
              addresses={@checkout.addresses}
              selected={@checkout.billing_address}
              name="checkout[billing_address_id]"
              prefix="billing"
            />
            <.manage_addresses empty?={@checkout.addresses == []} />
          </.step>

          <.step number={2} title={gettext("Shipping method")} id="shipping-step">
            <div class="space-y-2">
              <label
                :for={{method, cost} <- @checkout.shipping_options}
                class={[
                  "flex items-center gap-3 rounded-box border p-3 cursor-pointer transition-colors",
                  if(method == @checkout.shipping_method,
                    do: "border-primary bg-primary/5",
                    else: "border-base-300 hover:border-primary/50"
                  )
                ]}
              >
                <input
                  type="radio"
                  name="checkout[shipping_method]"
                  value={method}
                  checked={method == @checkout.shipping_method}
                  class="radio radio-primary radio-sm"
                  id={"shipping-#{method}"}
                />
                <span class="flex-1">
                  <span class="font-semibold">{Shipping.label(method)}</span>
                  <span
                    :if={method == :pickup && Brand.get(:address)}
                    class="block text-sm text-base-content/70"
                  >
                    {Brand.get(:address)}
                  </span>
                  <span :if={method == :freight} class="block text-sm text-base-content/70">
                    {gettext("We confirm the exact freight costs before delivery.")}
                  </span>
                  <span :if={free_from(method, @checkout)} class="block text-sm text-base-content/70">
                    {gettext("Free from %{amount}",
                      amount: Format.money(free_from(method, @checkout), @locale)
                    )}
                  </span>
                </span>
                <span class="font-semibold">{cost_text(cost, @locale)}</span>
              </label>
            </div>
          </.step>

          <.step
            :if={@checkout.shipping_method != :pickup}
            number={3}
            title={gettext("Delivery address")}
            id="delivery-step"
          >
            <.address_choice
              addresses={@checkout.delivery_addresses}
              selected={@checkout.shipping_address}
              name="checkout[shipping_address_id]"
              prefix="delivery"
            />
            <p :if={@checkout.delivery_addresses == []} class="text-sm" id="no-delivery-address">
              {gettext("We deliver to: %{countries}.", countries: delivery_countries())}
            </p>
            <.manage_addresses empty?={@checkout.delivery_addresses == []} />
          </.step>

          <.step number={payment_step(@checkout)} title={gettext("Payment method")} id="payment-step">
            <div class="space-y-2">
              <label
                :for={method <- @checkout.payment_methods}
                class={[
                  "flex items-center gap-3 rounded-box border p-3 cursor-pointer transition-colors",
                  if(method == @checkout.payment_method,
                    do: "border-primary bg-primary/5",
                    else: "border-base-300 hover:border-primary/50"
                  )
                ]}
              >
                <input
                  type="radio"
                  name="checkout[payment_method]"
                  value={method}
                  checked={method == @checkout.payment_method}
                  class="radio radio-primary radio-sm"
                  id={"payment-#{method}"}
                />
                <span class="font-semibold">{Payment.label(method)}</span>
              </label>
            </div>
          </.step>

          <.step number={payment_step(@checkout) + 1} title={gettext("Your order")} id="review-step">
            <ul class="divide-y divide-base-300" id="checkout-items">
              <li
                :for={line <- @checkout.pricing.lines}
                class="flex justify-between gap-4 py-2"
                id={"checkout-item-#{line.item.id}"}
              >
                <div>
                  <p class="font-semibold">
                    {Format.quantity(line.item.quantity, quantity_unit(line), @locale)}
                    {Unit.symbol(quantity_unit(line))}
                    {Translated.t(line.product.title, @locale)}
                  </p>
                  <p class="text-sm text-base-content/70">
                    {line.item.config_number || line.variant.number}
                    <span :if={line.variant.name}>· {Translated.t(line.variant.name, @locale)}</span>
                  </p>
                  <p :if={line.item.selections != %{}} class="text-xs text-base-content/60">
                    {Configurator.describe(line.product, line.item.selections, @locale)}
                  </p>
                  <p :if={!line.available?} class="text-sm text-error">
                    {gettext("No longer available")}
                  </p>
                </div>
                <span :if={line.available?} class="font-semibold whitespace-nowrap">
                  {Format.money(line.gross, @locale)}
                </span>
              </li>
            </ul>

            <label class="floating-label mt-4 block">
              <span>{gettext("Note (optional)")}</span>
              <textarea
                name="checkout[note]"
                class="textarea w-full"
                rows="2"
                maxlength="2000"
                placeholder={gettext("Note (optional)")}
                id="checkout-note"
                phx-debounce="500"
              >{@params["note"]}</textarea>
            </label>
          </.step>
        </div>

        <aside class="card h-fit bg-base-100 shadow-sm lg:sticky lg:top-4" id="checkout-totals">
          <div class="card-body gap-2">
            <h2 class="card-title">{gettext("Summary")}</h2>
            <div class="flex justify-between">
              <span>{gettext("Goods")}</span>
              <span id="goods-total">{Format.money(@checkout.totals.goods_gross, @locale)}</span>
            </div>
            <div class="flex justify-between">
              <span>{gettext("Shipping")}</span>
              <span id="shipping-total">{cost_text(@checkout.shipping_cost, @locale)}</span>
            </div>
            <div class="flex justify-between border-t border-base-300 pt-2 text-lg font-bold">
              <span>{gettext("Total")}</span>
              <span id="checkout-total">{Format.money(@checkout.totals.gross, @locale)}</span>
            </div>
            <div
              :for={line <- @checkout.totals.vat_lines}
              class="flex justify-between text-sm text-base-content/70"
            >
              <span>{gettext("incl. VAT %{rate} %", rate: Format.percent(line.rate))}</span>
              <span>{Format.money(line.vat, @locale)}</span>
            </div>

            <label class="label mt-2 items-start whitespace-normal text-base-content">
              <input type="hidden" name="checkout[gtc]" value="false" />
              <input
                type="checkbox"
                name="checkout[gtc]"
                value="true"
                checked={@params["gtc"] == "true"}
                class="checkbox checkbox-primary checkbox-sm mt-0.5"
                id="checkout-gtc"
              />
              <span>
                {gettext("I accept the")}
                <.link href={~p"/terms"} target="_blank" class="link link-primary">
                  {gettext("terms and conditions")}
                </.link>.
              </span>
            </label>

            <ul :if={@problems != []} class="space-y-1 text-sm text-error" id="checkout-problems">
              <li :for={{field, message} <- @problems} id={"problem-#{field}"}>{message}</li>
            </ul>

            <button
              type="submit"
              class="btn btn-primary mt-2"
              id="place-order"
              phx-disable-with={gettext("Ordering …")}
            >
              {gettext("Place binding order")}
            </button>
            <.link
              navigate={~p"/basket"}
              class="link link-hover text-center text-sm"
              id="back-to-basket"
            >
              {gettext("Back to basket")}
            </.link>
          </div>
        </aside>
      </.form>
    </Layouts.app>
    """
  end

  attr :number, :integer, required: true
  attr :title, :string, required: true
  attr :id, :string, required: true
  slot :inner_block, required: true

  defp step(assigns) do
    ~H"""
    <section class="card bg-base-100 shadow-sm" id={@id}>
      <div class="card-body gap-3">
        <h2 class="card-title">
          <span class="badge badge-primary badge-sm">{@number}</span> {@title}
        </h2>
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :addresses, :list, required: true
  attr :selected, :map, default: nil
  attr :name, :string, required: true
  attr :prefix, :string, required: true

  defp address_choice(assigns) do
    ~H"""
    <div class="grid gap-2 sm:grid-cols-2">
      <label
        :for={address <- @addresses}
        class={[
          "flex items-start gap-3 rounded-box border p-3 cursor-pointer transition-colors",
          if(@selected && address.id == @selected.id,
            do: "border-primary bg-primary/5",
            else: "border-base-300 hover:border-primary/50"
          )
        ]}
      >
        <input
          type="radio"
          name={@name}
          value={address.id}
          checked={@selected && address.id == @selected.id}
          class="radio radio-primary radio-sm mt-1"
          id={"#{@prefix}-#{address.id}"}
        />
        <.address_lines address={address} />
      </label>
    </div>
    """
  end

  attr :empty?, :boolean, required: true

  defp manage_addresses(assigns) do
    ~H"""
    <.link
      navigate={~p"/account/addresses"}
      class={["w-fit", if(@empty?, do: "btn btn-primary btn-sm", else: "link link-hover text-sm")]}
    >
      {if(@empty?, do: gettext("Add an address"), else: gettext("Manage addresses"))}
    </.link>
    """
  end

  defp payment_step(%{shipping_method: :pickup}), do: 3
  defp payment_step(_checkout), do: 4

  defp cost_text(nil, _locale), do: "–"

  defp cost_text(%{gross: gross, estimate?: estimate?}, locale) do
    cond do
      Decimal.equal?(gross, 0) -> gettext("free")
      estimate? -> gettext("from %{amount}", amount: Format.money(gross, locale))
      true -> Format.money(gross, locale)
    end
  end

  defp free_from(method, %{shipping_address: %{country: country}}),
    do: Shipping.free_from(method, country)

  defp free_from(method, %{delivery_addresses: [%{country: country} | _]}),
    do: Shipping.free_from(method, country)

  defp free_from(_method, _checkout), do: nil

  defp delivery_countries do
    Mercator.Countries.delivery() |> Enum.map_join(", ", &Mercator.Countries.name/1)
  end

  # configurable products are counted in pieces; others in the variant's unit
  defp quantity_unit(%{product: %{kind: :configurable}}), do: :piece
  defp quantity_unit(line), do: line.variant.unit
end
