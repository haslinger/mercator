defmodule MercatorWeb.AddressesLive do
  @moduledoc """
  The customer's address book (`/account/addresses`, checkout step 2):
  add, edit and delete addresses, choose default billing and delivery
  addresses.
  """
  use MercatorWeb, :live_view

  alias Mercator.Accounts
  alias Mercator.Accounts.Address
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
    first? = socket.assigns.addresses == []

    form =
      Address
      |> AshPhoenix.Form.for_create(:create,
        actor: socket.assigns.current_user,
        params: %{
          "name" => socket.assigns.current_user.name,
          "country" => "AT",
          "default_billing" => first?,
          "default_shipping" => first?
        }
      )
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    address = Enum.find(socket.assigns.addresses, &(&1.id == id))

    form =
      address
      |> AshPhoenix.Form.for_update(:update, actor: socket.assigns.current_user)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("cancel", _params, socket), do: {:noreply, assign(socket, :form, nil)}

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
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
      nav_categories={@nav_categories}
      basket_count={@basket_count}
    >
      <.link navigate={~p"/account"} class="link link-hover text-sm" id="back-to-account">
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

      <div :if={@form} class="modal modal-open" id="address-modal">
        <div class="modal-box max-w-xl">
          <h2 class="text-xl font-bold">{gettext("Address")}</h2>
          <.form for={@form} id="address-form" phx-change="validate" phx-submit="save" class="mt-4">
            <.input field={@form[:name]} label={gettext("Name")} />
            <.input field={@form[:company]} label={gettext("Company (optional)")} />
            <.input field={@form[:street]} label={gettext("Street and number")} />
            <div class="grid gap-3 sm:grid-cols-3">
              <.input field={@form[:postcode]} label={gettext("Postcode")} />
              <div class="sm:col-span-2"><.input field={@form[:city]} label={gettext("City")} /></div>
            </div>
            <.input
              field={@form[:country]}
              type="select"
              label={gettext("Country")}
              options={Countries.options(Countries.billing())}
            />
            <div class="grid gap-3 sm:grid-cols-2">
              <.input field={@form[:phone]} type="tel" label={gettext("Phone (optional)")} />
              <.input field={@form[:vat_id]} label={gettext("VAT ID (businesses, optional)")} />
            </div>
            <.input
              field={@form[:default_billing]}
              type="checkbox"
              label={gettext("Default billing address")}
            />
            <.input
              field={@form[:default_shipping]}
              type="checkbox"
              label={gettext("Default delivery address")}
            />
            <div class="modal-action">
              <button type="button" phx-click="cancel" class="btn btn-ghost">{gettext("Cancel")}</button>
              <button type="submit" class="btn btn-primary" id="save-address">{gettext("Save")}</button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :address, :map, required: true

  @doc "An address as lines of text."
  def address_lines(assigns) do
    ~H"""
    <address class="not-italic leading-relaxed">
      <span :if={@address.company} class="block font-semibold">{@address.company}</span>
      <span class="block">{@address.name}</span>
      <span class="block">{@address.street}</span>
      <span class="block">{@address.postcode} {@address.city}</span>
      <span class="block">{Countries.name(@address.country)}</span>
      <span :if={@address.phone} class="block text-sm text-base-content/70">{@address.phone}</span>
      <span :if={@address.vat_id} class="block text-sm text-base-content/70">{gettext("VAT ID")}: {@address.vat_id}</span>
    </address>
    """
  end
end
