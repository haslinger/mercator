defmodule MercatorWeb.OrdersLive do
  @moduledoc """
  The signed-in customer's order history (`/account/orders`), newest first.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OrderComponents, only: [state_badge: 1]

  alias Mercator.Sales
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    orders = Sales.list_my_orders!(actor: socket.assigns.current_user, load: [:item_count])

    {:ok,
     socket
     |> assign(:page_title, gettext("My orders"))
     |> assign(:orders_empty?, orders == [])
     |> stream(:orders, orders)}
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
      <.link navigate={~p"/account"} class="link link-hover text-sm w-fit" id="back-to-account">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("My account")}
      </.link>
      <h1 class="text-3xl font-bold">{gettext("My orders")}</h1>

      <div :if={@orders_empty?} class="card bg-base-100 shadow-sm" id="no-orders">
        <div class="card-body items-start">
          <p>{gettext("You have not placed any orders yet.")}</p>
          <.link navigate={~p"/"} class="btn btn-primary btn-sm">{gettext("Start shopping")}</.link>
        </div>
      </div>

      <ul id="orders" phx-update="stream" class="space-y-3">
        <li :for={{dom_id, order} <- @streams.orders} id={dom_id}>
          <.link
            navigate={~p"/account/orders/#{order.number}"}
            class="card bg-base-100 shadow-sm transition hover:shadow-md"
          >
            <div class="card-body flex-row flex-wrap items-center justify-between gap-x-6 gap-y-2 py-4">
              <div>
                <p class="font-semibold">{order.number}</p>
                <p class="text-sm text-base-content/70">
                  {Format.date(order.inserted_at)} · {ngettext(
                    "1 item",
                    "%{count} items",
                    order.item_count
                  )}
                </p>
              </div>
              <div class="flex items-center gap-4">
                <.state_badge state={order.state} shipping_method={order.shipping_method} />
                <span class="font-semibold whitespace-nowrap">
                  {Format.money(order.gross, @locale)}
                </span>
                <.icon name="hero-chevron-right" class="size-4 text-base-content/50" />
              </div>
            </div>
          </.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
