defmodule MercatorWeb.OrderLive do
  @moduledoc """
  An order of the signed-in customer (`/account/orders/:number`): items,
  totals, payment instructions and addresses. Also the confirmation page
  after checkout.

  Orders paid online (phase 7) can be paid (again) from here; the provider
  sends the customer back to `/account/orders/:number/payment`, where the
  status is fetched from the provider before showing the order.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OrderComponents

  alias Mercator.{Payments, Sales}
  alias Mercator.Sales.Payment
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"number" => number}, _session, socket) do
    case load_order(number, socket.assigns.current_user) do
      {:ok, order} ->
        {:ok, socket |> assign(:page_title, order.number) |> assign_order(order)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Order not found."))
         |> push_navigate(to: ~p"/account/orders")}
    end
  end

  # back from the payment provider: ask it how the payment ended
  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :payment, order: order}} = socket) do
    if connected?(socket), do: back_from_payment(socket, order), else: {:noreply, socket}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  defp back_from_payment(socket, order) do
    payment = Payments.sync_latest(order)
    {:ok, order} = load_order(order.number, socket.assigns.current_user)

    {:noreply,
     socket
     |> assign_order(order)
     |> payment_flash(payment)
     |> push_patch(to: ~p"/account/orders/#{order.number}", replace: true)}
  end

  @impl true
  def handle_event("pay", _params, socket) do
    case Payments.start(socket.assigns.order) do
      {:ok, checkout_url} ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("The payment could not be started. Please try again later.")
         )}
    end
  end

  defp load_order(number, user),
    do: Sales.get_order_by_number(number, actor: user, load: [:items])

  defp assign_order(socket, order) do
    socket
    |> assign(:order, order)
    |> assign(:payable?, Payments.payable?(order))
    |> assign(:last_payment, Payments.latest(order))
  end

  defp payment_flash(socket, %{status: :paid}),
    do: put_flash(socket, :info, gettext("Thank you, your payment has been received."))

  defp payment_flash(socket, %{status: status}) when status in [:open, :pending],
    do:
      put_flash(
        socket,
        :info,
        gettext("Your payment is being processed. We will confirm it by email.")
      )

  defp payment_flash(socket, %{status: _failed}),
    do: put_flash(socket, :error, gettext("The payment was not completed. You can try again."))

  defp payment_flash(socket, nil), do: socket

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
      <.link navigate={~p"/account/orders"} class="link link-hover text-sm w-fit" id="back-to-orders">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("My orders")}
      </.link>
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h1 class="text-3xl font-bold" id="order-number">
          {gettext("Order %{number}", number: @order.number)}
        </h1>
        <.state_badge
          state={@order.state}
          shipping_method={@order.shipping_method}
          id="order-state"
        />
      </div>
      <p class="text-sm text-base-content/70">
        {gettext("Ordered on %{date}", date: Format.date(@order.inserted_at))}
        <.link
          href={~p"/account/orders/#{@order.number}/pdf"}
          class="link ml-2"
          id="order-pdf"
        >
          <.icon name="hero-document-arrow-down" class="size-4" /> {gettext(
            "Order confirmation (PDF)"
          )}
        </.link>
      </p>

      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <div class="space-y-6">
          <section class="card bg-base-100 shadow-sm" id="order-payment">
            <div class="card-body gap-1">
              <h2 class="card-title">{gettext("Payment")}: {Payment.label(@order.payment_method)}</h2>
              <p :for={line <- Payment.instructions(@order)} class="first:mb-1">{line}</p>
              <p
                :if={
                  (@payable? and @last_payment) &&
                    @last_payment.status in [:failed, :canceled, :expired]
                }
                class="text-sm text-error"
                id="payment-not-completed"
              >
                {gettext("The last payment was not completed.")}
              </p>
              <button
                :if={@payable?}
                type="button"
                phx-click="pay"
                class="btn btn-primary mt-2 w-fit"
                id="pay-now"
              >
                <.icon name="hero-credit-card" class="size-5" /> {gettext("Pay now")}
              </button>
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
