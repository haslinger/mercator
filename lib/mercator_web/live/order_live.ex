defmodule MercatorWeb.OrderLive do
  @moduledoc """
  An order of the signed-in customer (`/account/orders/:number`): items,
  totals, payment instructions and addresses. Also the confirmation page
  after checkout.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OrderComponents

  alias Mercator.Sales
  alias Mercator.Sales.Payment

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

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
        <.state_badge state={@order.state} id="order-state" />
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
              <.order_items order={@order} locale={@locale} />
              <p :if={@order.note} class="text-sm" id="order-note">
                <span class="font-semibold">{gettext("Your note")}:</span> {@order.note}
              </p>
            </div>
          </section>

          <.order_addresses order={@order} />
        </div>

        <.order_totals order={@order} locale={@locale} />
      </div>
    </Layouts.app>
    """
  end
end
