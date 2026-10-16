defmodule MercatorWeb.AddressesLive do
  @moduledoc """
  The customer's address book (`/account/addresses`, checkout step 2):
  add, edit and delete addresses, choose default billing and delivery
  addresses. The checkout adds and edits addresses in the same dialog
  (`MercatorWeb.AddressComponents`).
  """
  use MercatorWeb, :live_view

  import MercatorWeb.AddressComponents

  alias Mercator.Accounts
  alias Mercator.Countries

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: gettext("My addresses"), form: nil) |> load()}
  end

  defp load(socket) do
    assign(socket, :addresses, Accounts.list_my_addresses!(actor: socket.assigns.current_user))
  end

  @impl true
  def handle_event("new", _params, socket) do
    form = new_address_form(socket.assigns.current_user, socket.assigns.addresses == [])
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    address = Enum.find(socket.assigns.addresses, &(&1.id == id))
    {:noreply, assign(socket, :form, edit_address_form(address, socket.assigns.current_user))}
  end

  def handle_event("cancel_address", _params, socket), do: {:noreply, assign(socket, :form, nil)}

  def handle_event("validate_address", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save_address", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _} ->
        {:noreply,
         socket |> assign(:form, nil) |> put_flash(:info, gettext("Address saved.")) |> load()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("default", %{"id" => id, "kind" => kind}, socket)
      when kind in ~w(billing shipping) do
    address = Enum.find(socket.assigns.addresses, &(&1.id == id))

    Accounts.update_address!(address, %{"default_#{kind}" => true},
      actor: socket.assigns.current_user
    )

    {:noreply, load(socket)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    address = Enum.find(socket.assigns.addresses, &(&1.id == id))
    Accounts.destroy_address!(address, actor: socket.assigns.current_user)
    {:noreply, socket |> put_flash(:info, gettext("Address deleted.")) |> load()}
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
      <.link
        navigate={~p"/account"}
        class="link link-hover text-sm"
        id="back-to-account"
      >
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("My account")}
      </.link>
      <div class="flex items-center justify-between">
        <h1 class="text-3xl font-bold">{gettext("My addresses")}</h1>
        <button type="button" phx-click="new" class="btn btn-primary" id="new-address">
          <.icon name="hero-plus" class="size-5" /> {gettext("New address")}
        </button>
      </div>

      <p :if={@addresses == []} class="text-base-content/70" id="no-addresses">
        {gettext("You have not saved any addresses yet.")}
      </p>

      <div class="grid gap-4 md:grid-cols-2" id="addresses">
        <div
          :for={address <- @addresses}
          class="card bg-base-100 shadow-sm"
          id={"address-#{address.id}"}
        >
          <div class="card-body gap-2">
            <div class="flex flex-wrap gap-1">
              <span :if={address.default_billing} class="badge badge-primary badge-sm">{gettext(
                "Billing address"
              )}</span>
              <span :if={address.default_shipping} class="badge badge-secondary badge-sm">{gettext(
                "Delivery address"
              )}</span>
            </div>
            <.address_lines address={address} />
            <div class="card-actions mt-2 flex-wrap">
              <button
                :if={!address.default_billing}
                type="button"
                phx-click="default"
                phx-value-id={address.id}
                phx-value-kind="billing"
                class="btn btn-ghost btn-xs"
                id={"default-billing-#{address.id}"}
              >
                {gettext("Use for billing")}
              </button>
              <button
                :if={!address.default_shipping and address.country in Countries.delivery()}
                type="button"
                phx-click="default"
                phx-value-id={address.id}
                phx-value-kind="shipping"
                class="btn btn-ghost btn-xs"
                id={"default-shipping-#{address.id}"}
              >
                {gettext("Use for delivery")}
              </button>
              <button
                type="button"
                phx-click="edit"
                phx-value-id={address.id}
                class="btn btn-ghost btn-xs"
                id={"edit-address-#{address.id}"}
              >
                {gettext("Edit")}
              </button>
              <button
                type="button"
                phx-click="delete"
                phx-value-id={address.id}
                data-confirm={gettext("Delete this address?")}
                class="btn btn-ghost btn-xs text-error"
                id={"delete-address-#{address.id}"}
              >
                {gettext("Delete")}
              </button>
            </div>
          </div>
        </div>
      </div>

      <.address_modal :if={@form} form={@form} />
    </Layouts.app>
    """
  end
end
