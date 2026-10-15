defmodule MercatorWeb.PaymentSimulatorLive do
  @moduledoc """
  The "payment page" of `Mercator.Payments.Simulator` (dev, tests, demo):
  stands in for a provider's hosted page. Every step says clearly that it is
  a simulation and that no real data may be entered; test data is listed.

    * card: test cards (one paid, one declined)
    * EPS: choose a fictional bank, log in to its simulated online banking,
      confirm with a TAN (one confirms, one is rejected)
    * cancel

  The outcome is reported like a provider's webhook would
  (`Mercator.Payments.notify/2`); then the customer goes back to the shop.
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
           step: :start,
           bank: nil,
           form: to_form(%{}, as: :card),
           error: nil
         )}

      {:error, _not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This payment does not exist (any more)."))
         |> push_navigate(to: ~p"/")}
    end
  end

  # --- card ---

  @impl true
  def handle_event("pay_card", %{"card" => card}, socket) do
    case Simulator.pay_by_card(
           socket.assigns.payment.id,
           card["number"],
           card["expiry"],
           card["cvc"]
         ) do
      {:ok, payment} -> back_to_shop(socket, payment)
      {:error, reason} -> {:noreply, error(socket, reason, to_form(card, as: :card))}
    end
  end

  # --- EPS: bank, login, TAN ---

  def handle_event("eps", _params, socket),
    do: {:noreply, step(socket, :eps_bank, to_form(%{}, as: :eps))}

  def handle_event("eps_bank", %{"eps" => %{"bank" => bank}}, socket) do
    if bank in Simulator.eps_banks(),
      do: {:noreply, socket |> assign(:bank, bank) |> step(:eps_login, to_form(%{}, as: :eps))},
      else: {:noreply, error(socket, :no_bank, socket.assigns.form)}
  end

  def handle_event("eps_login", %{"eps" => eps}, socket) do
    case Simulator.eps_login(eps["user_number"], eps["pin"]) do
      :ok ->
        {:noreply, step(socket, :eps_tan, to_form(%{}, as: :eps))}

      {:error, reason} ->
        {:noreply, error(socket, reason, to_form(Map.delete(eps, "pin"), as: :eps))}
    end
  end

  def handle_event("eps_tan", %{"eps" => %{"tan" => tan}}, socket) do
    case Simulator.pay_by_eps(socket.assigns.payment.id, tan) do
      {:ok, payment} -> back_to_shop(socket, payment)
      {:error, reason} -> {:noreply, error(socket, reason, to_form(%{}, as: :eps))}
    end
  end

  def handle_event("back", _params, socket),
    do: {:noreply, socket |> assign(:bank, nil) |> step(:start, to_form(%{}, as: :card))}

  # --- cancel ---

  def handle_event("cancel", _params, socket) do
    case Simulator.complete(socket.assigns.payment.id, :canceled) do
      {:ok, payment} -> back_to_shop(socket, payment)
      {:error, reason} -> {:noreply, error(socket, reason, socket.assigns.form)}
    end
  end

  defp step(socket, step, form), do: assign(socket, step: step, form: form, error: nil)

  defp error(socket, reason, form), do: assign(socket, form: form, error: error_text(reason))

  # as the provider's webhook would, then back to the shop
  defp back_to_shop(socket, payment) do
    Payments.notify(:simulator, payment.id)
    {:noreply, redirect(socket, external: payment.return_url)}
  end

  defp error_text(:unknown_card), do: gettext("Unknown card. Please use one of the test cards.")
  defp error_text(:invalid_expiry), do: gettext("Please enter a valid expiry date (MM/YY).")
  defp error_text(:invalid_cvc), do: gettext("Please enter the 3 or 4 digit security code.")
  defp error_text(:no_bank), do: gettext("Please choose a bank.")

  defp error_text(:invalid_login),
    do: gettext("User number or PIN is wrong. Please use the test login.")

  defp error_text(:unknown_tan), do: gettext("Unknown TAN. Please use one of the test TANs.")
  defp error_text(:not_open), do: gettext("This payment is already decided.")
  defp error_text(_reason), do: gettext("The payment could not be processed.")

  # 4242424242424242 → "4242 4242 4242 4242"
  defp grouped(number),
    do: number |> String.graphemes() |> Enum.chunk_every(4) |> Enum.map_join(" ", &Enum.join/1)

  # --- rendering ---

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
          <.simulation_warning />

          <div>
            <p class="text-sm text-base-content/70">
              {gettext("Order %{number}", number: @payment.order_number)}
            </p>
            <p class="text-3xl font-bold" id="simulator-amount">
              {Format.money(@payment.amount, @locale)}
            </p>
          </div>

          <p :if={@payment.status != :open} class="text-base-content/70" id="simulator-decided">
            {gettext("This payment is already decided.")}
          </p>

          <div :if={@payment.status == :open} class="flex flex-col gap-4">
            <.start
              :if={@step == :start}
              form={@form}
              error={@error}
              amount={@payment.amount}
              locale={@locale}
            />
            <.eps_bank :if={@step == :eps_bank} form={@form} error={@error} />
            <.eps_login :if={@step == :eps_login} form={@form} error={@error} bank={@bank} />
            <.eps_tan
              :if={@step == :eps_tan}
              form={@form}
              error={@error}
              bank={@bank}
              amount={@payment.amount}
              locale={@locale}
            />

            <button type="button" phx-click="cancel" class="btn btn-ghost" id="simulate-canceled">
              {gettext("Cancel payment")}
            </button>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp simulation_warning(assigns) do
    ~H"""
    <div role="alert" class="alert alert-warning" id="simulation-warning">
      <.icon name="hero-beaker" class="size-6 shrink-0" />
      <div>
        <p class="font-bold">{gettext("Simulation – no real payment")}</p>
        <p class="text-sm">
          {gettext(
            "Please do not enter real card or bank details here, only the test data shown. A real provider shows its own payment page instead."
          )}
        </p>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :error, :string, default: nil
  attr :amount, :any, required: true
  attr :locale, :string, required: true

  defp start(assigns) do
    ~H"""
    <.form for={@form} id="card-form" phx-submit="pay_card" class="space-y-1">
      <.input
        field={@form[:number]}
        label={gettext("Card number")}
        inputmode="numeric"
        autocomplete="off"
        placeholder="4242 4242 4242 4242"
      />
      <div class="grid grid-cols-2 gap-3">
        <.input
          field={@form[:expiry]}
          label={gettext("Valid until (MM/YY)")}
          autocomplete="off"
          placeholder="12/30"
        />
        <.input
          field={@form[:cvc]}
          label={gettext("Security code")}
          inputmode="numeric"
          autocomplete="off"
          placeholder="123"
        />
      </div>
      <p :if={@error} class="text-sm text-error" id="simulator-error">{@error}</p>
      <button type="submit" class="btn btn-primary w-full" id="pay-card">
        <.icon name="hero-credit-card" class="size-5" />
        {gettext("Pay %{amount}", amount: Format.money(@amount, @locale))}
      </button>
    </.form>

    <.test_data id="test-cards" title={gettext("Test cards")}>
      <li :for={{number, outcome} <- Simulator.test_cards()} class="flex justify-between gap-2">
        <span class="font-mono">{grouped(number)}</span>
        <.outcome outcome={outcome} />
      </li>
      <:note>{gettext("Any future expiry date and any security code.")}</:note>
    </.test_data>

    <div class="divider my-0">{gettext("or")}</div>

    <button type="button" phx-click="eps" class="btn btn-outline" id="pay-eps">
      <.icon name="hero-building-library" class="size-5" /> {gettext("Pay by EPS transfer")}
    </button>
    """
  end

  attr :form, :any, required: true
  attr :error, :string, default: nil

  defp eps_bank(assigns) do
    ~H"""
    <.form for={@form} id="eps-bank-form" phx-submit="eps_bank" class="space-y-2">
      <h2 class="text-lg font-semibold">{gettext("EPS transfer: choose your bank")}</h2>
      <label
        :for={bank <- Simulator.eps_banks()}
        class="flex cursor-pointer items-center gap-3 rounded-box border border-base-300 p-3"
      >
        <input type="radio" name={@form[:bank].name} value={bank} class="radio radio-sm" />
        <.icon name="hero-building-library" class="size-5 text-base-content/60" /> {bank}
      </label>
      <p :if={@error} class="text-sm text-error" id="simulator-error">{@error}</p>
      <div class="flex justify-between gap-2">
        <button type="button" phx-click="back" class="btn btn-ghost">{gettext("Back")}</button>
        <button type="submit" class="btn btn-primary" id="eps-continue">{gettext("Continue")}</button>
      </div>
    </.form>
    """
  end

  attr :form, :any, required: true
  attr :error, :string, default: nil
  attr :bank, :string, required: true

  defp eps_login(assigns) do
    ~H"""
    <.form for={@form} id="eps-login-form" phx-submit="eps_login" class="space-y-1">
      <h2 class="text-lg font-semibold">
        {gettext("Online banking of %{bank} (simulated)", bank: @bank)}
      </h2>
      <.input field={@form[:user_number]} label={gettext("User number")} autocomplete="off" />
      <.input field={@form[:pin]} type="password" label={gettext("PIN")} autocomplete="off" />
      <p :if={@error} class="text-sm text-error" id="simulator-error">{@error}</p>
      <div class="flex justify-between gap-2 pt-2">
        <button type="button" phx-click="back" class="btn btn-ghost">{gettext("Back")}</button>
        <button type="submit" class="btn btn-primary" id="eps-sign-in">{gettext("Sign in")}</button>
      </div>
    </.form>

    <.test_data id="test-login" title={gettext("Test login")}>
      <li class="flex justify-between gap-2">
        <span>{gettext("User number")}</span>
        <span class="font-mono">{elem(Simulator.eps_test_login(), 0)}</span>
      </li>
      <li class="flex justify-between gap-2">
        <span>{gettext("PIN")}</span>
        <span class="font-mono">{elem(Simulator.eps_test_login(), 1)}</span>
      </li>
    </.test_data>
    """
  end

  attr :form, :any, required: true
  attr :error, :string, default: nil
  attr :bank, :string, required: true
  attr :amount, :any, required: true
  attr :locale, :string, required: true

  defp eps_tan(assigns) do
    ~H"""
    <.form for={@form} id="eps-tan-form" phx-submit="eps_tan" class="space-y-1">
      <h2 class="text-lg font-semibold">
        {gettext("Online banking of %{bank} (simulated)", bank: @bank)}
      </h2>
      <p class="text-sm">
        {gettext("Confirm the transfer of %{amount} with a TAN.",
          amount: Format.money(@amount, @locale)
        )}
      </p>
      <.input field={@form[:tan]} label={gettext("TAN")} inputmode="numeric" autocomplete="off" />
      <p :if={@error} class="text-sm text-error" id="simulator-error">{@error}</p>
      <div class="flex justify-between gap-2 pt-2">
        <button type="button" phx-click="back" class="btn btn-ghost">{gettext("Back")}</button>
        <button type="submit" class="btn btn-primary" id="eps-confirm">
          {gettext("Confirm transfer")}
        </button>
      </div>
    </.form>

    <.test_data id="test-tans" title={gettext("Test TANs")}>
      <li :for={{tan, outcome} <- Simulator.eps_tans()} class="flex justify-between gap-2">
        <span class="font-mono">{tan}</span>
        <.outcome outcome={outcome} />
      </li>
    </.test_data>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true
  slot :note

  defp test_data(assigns) do
    ~H"""
    <div class="rounded-box border border-dashed border-warning bg-warning/10 p-3 text-sm" id={@id}>
      <p class="font-semibold">{@title}</p>
      <ul class="mt-1 space-y-1">{render_slot(@inner_block)}</ul>
      <p :for={note <- @note} class="mt-1 text-base-content/70">{render_slot(note)}</p>
    </div>
    """
  end

  attr :outcome, :atom, required: true

  defp outcome(assigns) do
    ~H"""
    <span class={if @outcome == :paid, do: "text-success", else: "text-error"}>
      {if @outcome == :paid, do: gettext("paid"), else: gettext("declined")}
    </span>
    """
  end
end
