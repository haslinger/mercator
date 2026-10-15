defmodule MercatorWeb.Admin.OrderShowLive do
  @moduledoc """
  An order in the back office (`/admin/orders/:number`, checkout step 6):
  items, addresses, totals, customer and payment, state changes with a note
  and the history of changes. Cancelling needs a reason; confirming an order
  with estimated freight costs needs the final shipping costs.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OrderComponents

  alias Mercator.{Payments, Sales}
  alias Mercator.Sales.Changes.RecordStateChange
  alias Mercator.Sales.Payment
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  # target state => order action
  @transitions [
    confirmed: :confirm_order,
    paid: :mark_order_paid,
    shipped: :ship_order,
    completed: :complete_order,
    cancelled: :cancel_order
  ]

  @impl true
  def mount(%{"number" => number}, _session, socket) do
    case load_order(number, socket.assigns.current_user) do
      {:ok, order} ->
        {:ok,
         socket
         |> assign(:page_title, order.number)
         |> assign_order(order)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Order not found."))
         |> push_navigate(to: ~p"/admin/orders")}
    end
  end

  defp load_order(number, actor) do
    with {:ok, order} <-
           Sales.get_order_by_number(number,
             actor: actor,
             load: [:items, :events, :online_payments]
           ) do
      # Staff may not read user records; only the name of whoever made a change is shown.
      {:ok, Ash.load!(order, [events: [:user], user: []], authorize?: false)}
    end
  end

  defp assign_order(socket, order) do
    socket
    |> assign(:order, order)
    |> assign(:email_states, RecordStateChange.email_states())
    |> assign(:paid_payment, Enum.find(order.online_payments, &(&1.status == :paid)))
    |> assign(
      :next_states,
      Enum.filter(
        Keyword.keys(@transitions),
        &(&1 in AshStateMachine.possible_next_states(order))
      )
    )
    |> assign(
      :form,
      to_form(%{"note" => "", "shipping_gross" => "", "notify" => "true", "refund" => "true"},
        as: :change
      )
    )
  end

  @impl true
  def handle_event("transition", %{"to" => to} = params, socket) do
    order = socket.assigns.order
    input = Map.get(params, "change", %{})
    state = Enum.find(socket.assigns.next_states, &(to_string(&1) == to))

    with {:ok, state} <- check_state(state),
         {:ok, args} <- transition_args(state, order, input),
         {:ok, _order} <-
           apply(Sales, @transitions[state], [order, args, [actor: socket.assigns.current_user]]) do
      refunded = refund_on_cancel(state, input, socket)
      {:ok, order} = load_order(order.number, socket.assigns.current_user)

      changed =
        gettext("Order is now: %{state}", state: state_label(state, order.shipping_method))

      {:noreply,
       socket
       |> refund_flash(refunded, changed)
       |> assign_order(order)}
    else
      {:error, message} when is_binary(message) ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> assign(:form, to_form(input, as: :change))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("The state could not be changed."))}
    end
  end

  def handle_event("refund", %{"id" => id}, socket) do
    %{order: order, paid_payment: payment, current_user: actor} = socket.assigns

    if (order.state == :cancelled and payment) && payment.id == id do
      refunded = Payments.refund(payment, actor)
      {:ok, order} = load_order(order.number, actor)

      {:noreply,
       socket
       |> refund_flash(refunded, nil)
       |> assign_order(order)}
    else
      {:noreply, put_flash(socket, :error, gettext("This payment cannot be refunded."))}
    end
  end

  # cancelling a paid online order refunds it, unless staff unticked that
  defp refund_on_cancel(:cancelled, %{"refund" => "false"}, _socket), do: :none

  defp refund_on_cancel(:cancelled, _input, %{assigns: %{paid_payment: %{} = payment}} = socket),
    do: Payments.refund(payment, socket.assigns.current_user)

  defp refund_on_cancel(_state, _input, _socket), do: :none

  defp refund_flash(socket, refunded, message) do
    {kind, refund_message} = refund_message(refunded)
    put_flash(socket, kind, Enum.join(Enum.reject([message, refund_message], &is_nil/1), " "))
  end

  defp refund_message(:none), do: {:info, nil}
  defp refund_message({:ok, _payment}), do: {:info, gettext("The online payment was refunded.")}

  defp refund_message({:error, _reason}),
    do:
      {:error,
       gettext(
         "The online payment could not be refunded; please refund it in the provider's dashboard."
       )}

  defp check_state(nil), do: {:error, gettext("This state change is not possible.")}
  defp check_state(state), do: {:ok, state}

  defp transition_args(state, order, input) do
    note = blank_to_nil(input["note"])
    notify = input["notify"] != "false"

    cond do
      state == :cancelled and is_nil(note) ->
        {:error, gettext("Please enter a reason for the cancellation.")}

      state == :confirmed and order.shipping_estimate ->
        case Decimal.parse(String.replace(input["shipping_gross"] || "", ",", ".")) do
          {amount, ""} -> {:ok, %{note: note, notify: notify, shipping_gross: amount}}
          _ -> {:error, gettext("Please enter the final shipping costs.")}
        end

      true ->
        {:ok, %{note: note, notify: notify}}
    end
  end

  defp blank_to_nil(value) do
    case String.trim(value || "") do
      "" -> nil
      value -> value
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      locale={@locale}
      active="orders"
    >
      <.link navigate={~p"/admin/orders"} class="link link-hover text-sm w-fit" id="back-to-orders">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("Orders")}
      </.link>
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h1 class="text-3xl font-bold" id="order-number">{@order.number}</h1>
        <.state_badge
          state={@order.state}
          shipping_method={@order.shipping_method}
          id="order-state"
          class="badge-lg"
        />
      </div>
      <p class="text-sm text-base-content/70">
        {gettext("Ordered on %{date}",
          date: Format.datetime(@order.inserted_at)
        )}
        <.link
          :if={@order.offer_id}
          navigate={~p"/admin/offers/#{@order.offer_id}"}
          class="link ml-2"
          id="order-offer"
        >
          {gettext("from an offer")}
        </.link>
        <.link
          href={~p"/admin/orders/#{@order.number}/pdf"}
          target="_blank"
          class="link ml-2"
          id="order-pdf"
        >
          <.icon name="hero-document-text" class="size-4" /> {gettext("Order confirmation (PDF)")}
        </.link>
        <.link
          navigate={~p"/admin/incidents/new?#{%{order: @order.number}}"}
          class="link ml-2"
          id="report-incident"
        >
          <.icon name="hero-exclamation-triangle" class="size-4" /> {gettext("Report incident")}
        </.link>
      </p>

      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <div class="space-y-6">
          <section class="card bg-base-100 shadow-sm" id="order-customer">
            <div class="card-body gap-1">
              <h2 class="card-title">{gettext("Customer")}</h2>
              <p>
                <a href={"mailto:#{@order.email}"} class="link">{@order.email}</a>
                <.link
                  :if={:administrator in @current_user.roles}
                  navigate={~p"/admin/users/#{@order.user_id}"}
                  class="link link-hover ml-2 text-sm"
                  id="customer-link"
                >
                  {gettext("User account")}
                </.link>
              </p>
              <p>{gettext("Payment")}: {Payment.label(@order.payment_method)}</p>
              <p :if={@order.note} class="mt-2" id="order-note">
                <span class="font-semibold">{gettext("Customer note")}:</span> {@order.note}
              </p>
            </div>
          </section>

          <section class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h2 class="card-title">{gettext("Items")}</h2>
              <.order_items order={@order} locale={@locale} />
            </div>
          </section>

          <.order_addresses order={@order} />

          <section
            :if={@order.online_payments != []}
            class="card bg-base-100 shadow-sm"
            id="order-payments"
          >
            <div class="card-body gap-2">
              <h2 class="card-title">{gettext("Online payment attempts")}</h2>
              <div class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>{gettext("Started")}</th>
                      <th>{gettext("Status")}</th>
                      <th>{gettext("Method")}</th>
                      <th class="text-right">{gettext("Amount")}</th>
                      <th>{gettext("Provider")}</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={payment <- @order.online_payments} id={"payment-#{payment.id}"}>
                      <td class="whitespace-nowrap">{Format.datetime(payment.inserted_at)}</td>
                      <td>
                        <.payment_status_badge status={payment.status} />
                        <span
                          :if={payment.refunded_at}
                          class="block text-xs text-base-content/60"
                        >
                          {Format.datetime(payment.refunded_at)}
                        </span>
                      </td>
                      <td>{payment.method || "–"}</td>
                      <td class="text-right whitespace-nowrap">
                        {Format.money(payment.amount, @locale)}
                      </td>
                      <td class="whitespace-nowrap">
                        <a
                          :if={payment.dashboard_url}
                          href={payment.dashboard_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="link"
                          id={"payment-dashboard-#{payment.id}"}
                        >
                          {payment.provider_id}
                          <.icon name="hero-arrow-top-right-on-square" class="size-3" />
                        </a>
                        <span :if={!payment.dashboard_url} class="font-mono text-xs">
                          {payment.provider_id}
                        </span>
                        <span class="block text-xs text-base-content/60">
                          {provider_name(payment.provider)}
                        </span>
                      </td>
                      <td class="text-right">
                        <button
                          :if={@order.state == :cancelled and payment.status == :paid}
                          type="button"
                          class="btn btn-xs btn-warning"
                          phx-click="refund"
                          phx-value-id={payment.id}
                          data-confirm={
                            gettext("Refund %{amount} to the customer?",
                              amount: Format.money(payment.amount, @locale)
                            )
                          }
                          id={"refund-#{payment.id}"}
                        >
                          {gettext("Refund")}
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </section>
        </div>

        <div class="space-y-6">
          <.order_totals order={@order} locale={@locale} />

          <section :if={@next_states != []} class="card bg-base-100 shadow-sm" id="order-actions">
            <div class="card-body gap-3">
              <h2 class="card-title">{gettext("Change state")}</h2>
              <.form for={@form} id="transition-form" phx-submit="transition">
                <.input
                  :if={@order.shipping_estimate and :confirmed in @next_states}
                  field={@form[:shipping_gross]}
                  type="text"
                  inputmode="decimal"
                  label={gettext("Final shipping costs (gross, €)")}
                />
                <.input
                  field={@form[:note]}
                  type="textarea"
                  label={gettext("Note (required for cancellation)")}
                />
                <p class="text-xs text-base-content/60">
                  {gettext(
                    "Notes are internal; only the reason for a cancellation is sent to the customer."
                  )}
                </p>
                <.input
                  :if={@paid_payment && :cancelled in @next_states}
                  field={@form[:refund]}
                  type="checkbox"
                  label={
                    gettext("When cancelling: refund the online payment (%{amount})",
                      amount: Format.money(@paid_payment.amount, @locale)
                    )
                  }
                />
                <.input
                  :if={Enum.any?(@next_states, &(&1 in @email_states))}
                  field={@form[:notify]}
                  type="checkbox"
                  label={gettext("Inform the customer by email")}
                />
                <div class="mt-2 flex flex-wrap gap-2">
                  <button
                    :for={state <- @next_states}
                    type="submit"
                    name="to"
                    value={state}
                    class={[
                      "btn btn-sm",
                      if(state == :cancelled, do: "btn-error btn-outline", else: "btn-primary")
                    ]}
                    id={"to-#{state}"}
                  >
                    {action_label(state, @order.shipping_method)}
                  </button>
                </div>
              </.form>
            </div>
          </section>

          <section class="card bg-base-100 shadow-sm" id="order-history">
            <div class="card-body gap-3">
              <h2 class="card-title">{gettext("History")}</h2>
              <ul class="timeline timeline-vertical timeline-compact">
                <li>
                  <div class="timeline-middle"><.icon name="hero-check-circle" class="size-4" /></div>
                  <div class="timeline-end mb-3">
                    <p class="text-sm font-semibold">{state_label(:placed)}</p>
                    <p class="text-xs text-base-content/70">
                      {Format.datetime(@order.inserted_at)}
                    </p>
                  </div>
                  <hr :if={@order.events != []} />
                </li>
                <li :for={{event, index} <- Enum.with_index(@order.events)} id={"event-#{event.id}"}>
                  <hr />
                  <div class="timeline-middle"><.icon name="hero-check-circle" class="size-4" /></div>
                  <div class="timeline-end mb-3">
                    <p class="text-sm font-semibold">
                      {state_label(event.to_state, @order.shipping_method)}
                    </p>
                    <p class="text-xs text-base-content/70">
                      {Format.datetime(event.inserted_at)}
                      <span :if={event.user}>· {event.user.name || event.user.email}</span>
                    </p>
                    <p :if={event.note} class="text-sm">{event.note}</p>
                    <p :if={event.customer_notified} class="text-xs text-base-content/60">
                      <.icon name="hero-envelope" class="size-3" /> {gettext("Customer informed")}
                    </p>
                  </div>
                  <hr :if={index < length(@order.events) - 1} />
                </li>
              </ul>
            </div>
          </section>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  # a provider no longer registered still shows its key
  defp provider_name(key) do
    case Mercator.Payments.provider(key) do
      nil -> key
      provider -> provider.name()
    end
  end

  defp action_label(:confirmed, _shipping_method), do: gettext("Confirm")
  defp action_label(:paid, _shipping_method), do: gettext("Mark as paid")
  defp action_label(:shipped, :pickup), do: gettext("Report ready for pickup")
  defp action_label(:shipped, _shipping_method), do: gettext("Mark as shipped")
  defp action_label(:completed, _shipping_method), do: gettext("Complete")
  defp action_label(:cancelled, _shipping_method), do: gettext("Cancel order")
end
