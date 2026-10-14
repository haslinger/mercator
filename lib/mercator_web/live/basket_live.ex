defmodule MercatorWeb.BasketLive do
  @moduledoc """
  The basket (`/basket`): items with live prices, quantities, removal,
  totals with VAT per rate, and the way to the checkout.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.CatalogComponents, only: [catalog_image: 1, first_image: 1]

  alias Mercator.Catalog.{Configurator, Unit}
  alias Mercator.Sales.{BasketPricing, Baskets}
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, gettext("Basket")) |> load()}
  end

  defp load(socket) do
    owner = socket.assigns.basket_owner
    pricing = owner |> Baskets.get() |> BasketPricing.calculate()

    socket
    |> assign(:pricing, pricing)
    |> assign(:basket_count, length(pricing.lines))
    |> assign(:checkout?, Enum.all?(pricing.lines, & &1.available?))
    |> assign_new(:quantity_errors, fn -> %{} end)
  end

  @impl true
  def handle_event("quantity", %{"item" => item_id, "quantity" => quantity}, socket) do
    case Baskets.update_quantity(socket.assigns.basket_owner, item_id, quantity) do
      {:ok, _} ->
        {:noreply, socket |> update(:quantity_errors, &Map.delete(&1, item_id)) |> load()}

      {:error, message} when is_binary(message) ->
        {:noreply, update(socket, :quantity_errors, &Map.put(&1, item_id, message))}

      {:error, _} ->
        {:noreply,
         update(socket, :quantity_errors, &Map.put(&1, item_id, gettext("Invalid quantity.")))}
    end
  end

  def handle_event("remove", %{"item" => item_id}, socket) do
    Baskets.remove(socket.assigns.basket_owner, item_id)
    {:noreply, load(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <h1 class="text-3xl font-bold">{gettext("Basket")}</h1>

      <div :if={@pricing.lines == []} class="card bg-base-100 shadow-sm" id="empty-basket">
        <div class="card-body items-center text-center">
          <.icon name="hero-shopping-cart" class="size-12 text-base-content/30" />
          <p>{gettext("Your basket is empty.")}</p>
          <.link navigate={~p"/"} class="btn btn-primary">{gettext("Continue shopping")}</.link>
        </div>
      </div>

      <div :if={@pricing.lines != []} class="grid gap-6 lg:grid-cols-[1fr_20rem]">
        <div class="space-y-3" id="basket-items">
          <div
            :for={line <- @pricing.lines}
            class="card card-side bg-base-100 shadow-sm"
            id={"item-#{line.item.id}"}
          >
            <figure class="w-28 shrink-0">
              <.catalog_image
                image={first_image(line.product)}
                label={Translated.t(line.product.title, @locale)}
                class="h-full"
              />
            </figure>
            <div class="card-body gap-1 p-4">
              <div class="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <.link
                    navigate={~p"/products/#{line.product.slug}"}
                    class="font-semibold link link-hover"
                  >
                    {Translated.t(line.product.title, @locale)}
                  </.link>
                  <p class="text-sm text-base-content/70">
                    {line.item.config_number || line.variant.number}
                    <span :if={line.variant.name}>· {Translated.t(line.variant.name, @locale)}</span>
                  </p>
                  <p
                    :if={line.item.selections != %{}}
                    class="text-xs text-base-content/60"
                    id={"config-#{line.item.id}"}
                  >
                    {Configurator.describe(line.product, line.item.selections, @locale)}
                  </p>
                  <p :if={!line.available?} class="text-sm text-error">
                    {gettext("No longer available")}
                  </p>
                </div>
                <p :if={line.available?} class="text-lg font-bold" id={"line-total-#{line.item.id}"}>
                  {Format.money(line.gross, @locale)}
                </p>
              </div>
              <div class="flex flex-wrap items-center gap-3">
                <form phx-change="quantity" phx-submit="quantity" id={"quantity-form-#{line.item.id}"}>
                  <input type="hidden" name="item" value={line.item.id} />
                  <label class="input input-sm w-36">
                    <input
                      type="text"
                      inputmode="decimal"
                      name="quantity"
                      value={Format.quantity(line.item.quantity, quantity_unit(line), @locale)}
                      phx-debounce="500"
                      aria-label={gettext("Quantity")}
                      id={"quantity-#{line.item.id}"}
                    />
                    <span class="text-xs text-base-content/60">{Unit.symbol(quantity_unit(line))}</span>
                  </label>
                </form>
                <span :if={@quantity_errors[line.item.id]} class="text-sm text-error">{@quantity_errors[
                  line.item.id
                ]}</span>
                <span :if={line.available?} class="text-sm text-base-content/60">
                  {gettext("%{price} net each", price: Format.money(line.unit_net, @locale))}
                </span>
                <button
                  type="button"
                  phx-click="remove"
                  phx-value-item={line.item.id}
                  class="btn btn-ghost btn-sm ml-auto text-error"
                  id={"remove-#{line.item.id}"}
                >
                  <.icon name="hero-trash" class="size-4" /> {gettext("Remove")}
                </button>
              </div>
            </div>
          </div>
        </div>

        <aside class="card h-fit bg-base-100 shadow-sm" id="basket-totals">
          <div class="card-body gap-2">
            <h2 class="card-title">{gettext("Summary")}</h2>
            <div class="flex justify-between">
              <span>{gettext("Net total")}</span>
              <span id="total-net">{Format.money(@pricing.net, @locale)}</span>
            </div>
            <div :for={{rate, vat} <- @pricing.vat_by_rate} class="flex justify-between text-sm">
              <span>{gettext("VAT %{rate} %", rate: Format.percent(rate))}</span>
              <span>{Format.money(vat, @locale)}</span>
            </div>
            <div class="flex justify-between border-t border-base-300 pt-2 text-lg font-bold">
              <span>{gettext("Total")}</span>
              <span id="total-gross">{Format.money(@pricing.gross, @locale)}</span>
            </div>
            <p class="text-xs text-base-content/60">
              {gettext("Plus shipping costs, calculated at checkout.")}
            </p>
            <.link
              navigate={if @current_user, do: ~p"/checkout"}
              href={if !@current_user, do: ~p"/checkout/sign-in"}
              class={["btn btn-primary mt-2", !@checkout? && "btn-disabled"]}
              id="to-checkout"
            >
              {gettext("Proceed to checkout")}
            </.link>
            <p :if={!@current_user} class="text-xs text-base-content/60">
              {gettext("You sign in or register in the next step.")}
            </p>
          </div>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  # configurable products are counted in pieces; others in the variant's unit
  defp quantity_unit(%{product: %{kind: :configurable}}), do: :piece
  defp quantity_unit(line), do: line.variant.unit
end
