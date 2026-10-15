defmodule MercatorWeb.PaymentSimulatorLive do
  @moduledoc """
  The "payment page" of `Mercator.Payments.Simulator` (dev, tests, demo):
  stands in for a provider's hosted page. The customer enters a card (test
  cards are listed: one is paid, one is declined), pays by EPS or cancels;
  then the simulator reports it like a provider's webhook would
  (`Mercator.Payments.notify/2`) and sends the customer back to the shop.
  """
  use MercatorWeb, :live_view

  alias Mercator.Payments
  alias Mercator.Payments.Simulator
  alias MercatorWeb.Format

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Simulator.fetch_payment(id) do
      {:ok, payment} ->
        {:ok,
         assign(socket,
           page_title: gettext("Payment simulator"),
           payment: payment,
           card_form: card_form(%{}),
           card_error: nil
         )}

      {:error, _not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This payment does not exist (any more)."))
         |> push_navigate(to: ~p"/")}
    end
  end

  defp card_form(params), do: to_form(params, as: :card)

  @impl true
  def handle_event("pay_card", %{"card" => card}, socket) do
    id = socket.assigns.payment.id

    case Simulator.pay_by_card(id, card["number"], card["expiry"], card["cvc"]) do
      {:ok, payment} ->
        back_to_shop(socket, payment)

      {:error, reason} ->
        {:noreply, assign(socket, card_form: card_form(card), card_error: card_error(reason))}
    end
  end

  def handle_event("decide", %{"outcome" => outcome} = params, socket) do
    outcome = Enum.find(Simulator.outcomes(), &(to_string(&1) == outcome))

    case outcome && Simulator.complete(socket.assigns.payment.id, outcome, params["method"]) do
      {:ok, payment} ->
        back_to_shop(socket, payment)

      _not_open ->
        {:noreply, put_flash(socket, :error, gettext("This payment is already decided."))}
    end
  end

  # as the provider's webhook would, then back to the shop
  defp back_to_shop(socket, payment) do
    Payments.notify(:simulator, payment.id)
    {:noreply, redirect(socket, external: payment.return_url)}
  end

  # 4242424242424242 → "4242 4242 4242 4242"
  defp grouped(number),
    do: number |> String.graphemes() |> Enum.chunk_every(4) |> Enum.map_join(" ", &Enum.join/1)

  defp card_error(:unknown_card),
    do: gettext("Unknown card. Please use one of the test cards.")

  defp card_error(:invalid_expiry), do: gettext("Please enter a valid expiry date (MM/YY).")
  defp card_error(:invalid_cvc), do: gettext("Please enter the 3 or 4 digit security code.")
  defp card_error(:not_open), do: gettext("This payment is already decided.")
  defp card_error(_reason), do: gettext("The payment could not be processed.")

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
      <section class="card mx-auto w-full max-w-md bg-base-100 shadow" id="payment-simulator">
        <div class="card-body gap-4">
          <div role="alert" class="alert alert-warning">
            <.icon name="hero-beaker" class="size-5" />
            <span>
              {gettext(
                "Payment simulator: no real payment. A real provider shows its own payment page here."
              )}
            </span>
          </div>

          <div>
            <p class="text-sm text-base-content/70">
              {gettext("Order %{number}", number: @payment.order_number)}
            </p>
            <p class="text-3xl font-bold" id="simulator-amount">
              {Format.money(@payment.amount, @locale)}
            </p>
          </div>

          <%= if @payment.status == :open do %>
            <.form for={@card_form} id="card-form" phx-submit="pay_card" class="space-y-1">
              <.input
                field={@card_form[:number]}
                label={gettext("Card number")}
                inputmode="numeric"
                autocomplete="off"
                placeholder="4242 4242 4242 4242"
              />
              <div class="grid grid-cols-2 gap-3">
                <.input
                  field={@card_form[:expiry]}
                  label={gettext("Valid until (MM/YY)")}
                  autocomplete="off"
                  placeholder="12/30"
                />
                <.input
                  field={@card_form[:cvc]}
                  label={gettext("Security code")}
                  inputmode="numeric"
                  autocomplete="off"
                  placeholder="123"
                />
              </div>
              <p :if={@card_error} class="text-sm text-error" id="card-error">{@card_error}</p>
              <button type="submit" class="btn btn-primary w-full" id="pay-card">
                <.icon name="hero-credit-card" class="size-5" />
                {gettext("Pay %{amount}", amount: Format.money(@payment.amount, @locale))}
              </button>
            </.form>

            <div class="rounded-box bg-base-200 p-3 text-sm" id="test-cards">
              <p class="font-semibold">{gettext("Test cards")}</p>
              <ul class="mt-1 space-y-1">
                <li
                  :for={{number, outcome} <- Simulator.test_cards()}
                  class="flex justify-between gap-2"
                >
                  <span class="font-mono">{grouped(number)}</span>
                  <span class={if outcome == :paid, do: "text-success", else: "text-error"}>
                    {if outcome == :paid, do: gettext("paid"), else: gettext("declined")}
                  </span>
                </li>
              </ul>
              <p class="mt-1 text-base-content/70">
                {gettext("Any future expiry date and any security code.")}
              </p>
            </div>

            <div class="divider my-0">{gettext("or")}</div>

            <button
              type="button"
              phx-click="decide"
              phx-value-outcome="paid"
              phx-value-method="eps"
              class="btn btn-outline"
              id="simulate-paid-eps"
            >
              <.icon name="hero-building-library" class="size-5" /> {gettext("Pay by EPS transfer")}
            </button>
            <button
              type="button"
              phx-click="decide"
              phx-value-outcome="canceled"
              class="btn btn-ghost"
              id="simulate-canceled"
            >
              {gettext("Cancel payment")}
            </button>
          <% else %>
            <p class="text-base-content/70" id="simulator-decided">
              {gettext("This payment is already decided.")}
            </p>
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
