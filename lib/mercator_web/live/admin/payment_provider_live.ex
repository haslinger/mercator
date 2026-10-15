defmodule MercatorWeb.Admin.PaymentProviderLive do
  @moduledoc """
  Switching the online payment provider (`/admin/payment-providers`,
  phase 7): administrators choose one of the providers registered for this
  deployment, or switch online payment off. Providers are set up in the
  deployment's configuration, not here (only switchable). Payments already
  started keep their provider.
  """
  use MercatorWeb, :live_view

  alias Mercator.Payments

  on_mount {MercatorWeb.LiveUserAuth, {:require_role, :administrator}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, gettext("Payment providers")) |> load()}
  end

  defp load(socket) do
    assign(socket,
      providers: Payments.providers(),
      active: Payments.active()
    )
  end

  @impl true
  def handle_event("activate", %{"key" => key}, socket) do
    key = if key == "", do: nil, else: key

    case Payments.activate(key, socket.assigns.current_user) do
      {:ok, _setting} ->
        message =
          if key,
            do:
              gettext("Online payment now goes through %{name}.", name: Payments.active().name()),
            else: gettext("Online payment is switched off.")

        {:noreply, socket |> load() |> put_flash(:info, message)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("This provider cannot be used."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      help={@help_chapter}
      locale={@locale}
      active="payment-providers"
    >
      <h1 class="text-3xl font-bold">{gettext("Payment providers")}</h1>
      <p class="max-w-2xl text-base-content/70">
        {gettext(
          "Choose which provider customers pay online with. Providers are set up for this shop by its operator; payments already started keep their provider."
        )}
      </p>

      <div class="grid max-w-2xl gap-3" id="payment-providers">
        <.provider_card
          key=""
          name={gettext("No online payment")}
          hint={gettext("Customers pay by the other payment methods only.")}
          active?={is_nil(@active)}
          available?={true}
        />
        <.provider_card
          :for={provider <- @providers}
          key={to_string(provider.key())}
          name={provider.name()}
          hint={provider.setup_hint()}
          active?={@active == provider}
          available?={provider.available?()}
        />
      </div>
      <p :if={@providers == []} class="text-sm text-base-content/70" id="no-providers">
        {gettext("No payment provider is set up for this shop.")}
      </p>
    </Layouts.admin>
    """
  end

  attr :key, :string, required: true
  attr :name, :string, required: true
  attr :hint, :string, default: nil
  attr :active?, :boolean, required: true
  attr :available?, :boolean, required: true

  defp provider_card(assigns) do
    ~H"""
    <div
      class={[
        "card bg-base-100 shadow-sm",
        @active? && "ring-2 ring-primary"
      ]}
      id={"provider-#{if @key == "", do: "none", else: @key}"}
    >
      <div class="card-body flex-row items-center gap-4 p-4">
        <div class="flex-1">
          <p class="font-semibold">{@name}</p>
          <p :if={@hint} class="text-sm text-base-content/70">{@hint}</p>
          <p :if={!@available?} class="text-sm text-warning">{gettext("Not set up")}</p>
        </div>
        <span :if={@active?} class="badge badge-primary">{gettext("Active")}</span>
        <button
          :if={!@active? and @available?}
          type="button"
          phx-click="activate"
          phx-value-key={@key}
          class="btn btn-sm"
          id={"activate-#{if @key == "", do: "none", else: @key}"}
        >
          {gettext("Use")}
        </button>
      </div>
    </div>
    """
  end
end
