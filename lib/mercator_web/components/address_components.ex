defmodule MercatorWeb.AddressComponents do
  @moduledoc """
  Addresses as shown and edited by the customer: in the address book
  (`MercatorWeb.AddressesLive`) and in the checkout's address dialog
  (`MercatorWeb.CheckoutLive`), plus the address lines used on orders and
  printed offers.
  """
  use MercatorWeb, :html

  alias Mercator.Accounts.Address
  alias Mercator.Countries

  @doc """
  A form for a new address of `user`. The first address becomes the default
  for billing and delivery.
  """
  def new_address_form(user, first?) do
    Address
    |> AshPhoenix.Form.for_create(:create,
      actor: user,
      params: %{
        "name" => user.name,
        "country" => "AT",
        "default_billing" => first?,
        "default_shipping" => first?
      }
    )
    |> to_form()
  end

  @doc "A form for changing `address`."
  def edit_address_form(address, user) do
    address
    |> AshPhoenix.Form.for_update(:update, actor: user)
    |> to_form()
  end

  attr :form, Phoenix.HTML.Form, required: true

  attr :countries, :list,
    default: nil,
    doc: "country codes to offer, default all billing countries"

  @doc """
  The address form in a modal. The host LiveView handles the events
  `validate_address`, `save_address` and `cancel_address`.
  """
  def address_modal(assigns) do
    assigns =
      assign_new(assigns, :country_codes, fn -> assigns.countries || Countries.billing() end)

    ~H"""
    <div class="modal modal-open" id="address-modal">
      <div class="modal-box max-w-xl">
        <h2 class="text-xl font-bold">{gettext("Address")}</h2>
        <.form
          for={@form}
          id="address-form"
          phx-change="validate_address"
          phx-submit="save_address"
          class="mt-4"
        >
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
            options={Countries.options(@country_codes)}
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
            <button type="button" phx-click="cancel_address" class="btn btn-ghost" id="cancel-address">
              {gettext("Cancel")}
            </button>
            <button type="submit" class="btn btn-primary" id="save-address">{gettext("Save")}</button>
          </div>
        </.form>
      </div>
      <div class="modal-backdrop" phx-click="cancel_address"></div>
    </div>
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
