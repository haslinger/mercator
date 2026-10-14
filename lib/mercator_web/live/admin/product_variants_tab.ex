defmodule MercatorWeb.Admin.ProductVariantsTab do
  @moduledoc """
  Product editor tab "variants & prices" (back office step 4b): variants
  (number, name, unit, stock, delivery time, weight, active), sortable by
  drag & drop, and their price rows (net, graduated, time-limited, promotion).

  A LiveComponent because the tab keeps its own editing state and events.
  """
  use MercatorWeb, :live_component

  import MercatorWeb.TranslatedComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.{Price, Unit, Variant}
  alias Mercator.Translated
  alias MercatorWeb.Format

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:variant_form, fn -> nil end)
     |> assign_new(:price_form, fn -> nil end)
     |> load()}
  end

  defp load(socket) do
    product =
      Catalog.get_product!(socket.assigns.product_id,
        actor: socket.assigns.current_user,
        load: [:tax_class, variants: :prices]
      )

    assign(socket, :product, product)
  end

  # --- events ---

  @impl true
  def handle_event("new_variant", _params, socket) do
    product = socket.assigns.product
    number = "#{product.number}-#{length(product.variants) + 1}"

    form =
      Variant
      |> AshPhoenix.Form.for_create(:create,
        actor: socket.assigns.current_user,
        params: %{"number" => number},
        transform_params: fn _form, params, _ ->
          Map.merge(params, %{
            "product_id" => product.id,
            "position" => next_position(product.variants)
          })
        end
      )
      |> to_form()

    {:noreply, assign(socket, variant_form: form, price_form: nil)}
  end

  def handle_event("edit_variant", %{"id" => id}, socket) do
    form =
      socket
      |> variant(id)
      |> AshPhoenix.Form.for_update(:update, actor: socket.assigns.current_user)
      |> to_form()

    {:noreply, assign(socket, variant_form: form, price_form: nil)}
  end

  def handle_event("validate_variant", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :variant_form, AshPhoenix.Form.validate(socket.assigns.variant_form, params))}
  end

  def handle_event("save_variant", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.variant_form, params: params) do
      {:ok, _variant} ->
        {:noreply, socket |> assign(:variant_form, nil) |> load()}

      {:error, form} ->
        {:noreply, assign(socket, :variant_form, form)}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, variant_form: nil, price_form: nil)}
  end

  def handle_event("delete_variant", %{"id" => id}, socket) do
    product = socket.assigns.product

    if product.state == :active and length(product.variants) == 1 do
      {:noreply,
       put_flash_message(socket, gettext("An active product needs at least one variant."))}
    else
      Catalog.destroy_variant!(variant(socket, id), actor: socket.assigns.current_user)
      {:noreply, load(socket)}
    end
  end

  def handle_event("reorder", %{"id" => id, "index" => index}, socket) do
    actor = socket.assigns.current_user

    socket.assigns.product.variants
    |> Enum.reject(&(&1.id == id))
    |> List.insert_at(index, variant(socket, id))
    |> Enum.with_index()
    |> Enum.each(fn {variant, position} ->
      if variant.position != position,
        do: Catalog.update_variant!(variant, %{position: position}, actor: actor)
    end)

    {:noreply, load(socket)}
  end

  def handle_event("new_price", %{"variant" => variant_id}, socket) do
    form =
      Price
      |> AshPhoenix.Form.for_create(:create,
        actor: socket.assigns.current_user,
        params: %{"min_quantity" => "1"},
        transform_params: fn _form, params, _ -> Map.put(params, "variant_id", variant_id) end
      )
      |> to_form()

    {:noreply, assign(socket, price_form: form, price_variant_id: variant_id, variant_form: nil)}
  end

  def handle_event("validate_price", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :price_form, AshPhoenix.Form.validate(socket.assigns.price_form, params))}
  end

  def handle_event("save_price", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.price_form, params: params) do
      {:ok, _price} -> {:noreply, socket |> assign(:price_form, nil) |> load()}
      {:error, form} -> {:noreply, assign(socket, :price_form, form)}
    end
  end

  def handle_event("delete_price", %{"id" => id}, socket) do
    price =
      socket.assigns.product.variants |> Enum.flat_map(& &1.prices) |> Enum.find(&(&1.id == id))

    Catalog.destroy_price!(price, actor: socket.assigns.current_user)
    {:noreply, load(socket)}
  end

  defp variant(socket, id), do: Enum.find(socket.assigns.product.variants, &(&1.id == id))

  defp next_position(variants),
    do: variants |> Enum.map(& &1.position) |> Enum.max(fn -> -1 end) |> Kernel.+(1)

  # flash messages belong to the LiveView
  defp put_flash_message(socket, message) do
    send(self(), {:flash, :error, message})
    socket
  end

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <div class="flex items-center justify-between">
        <p class="text-sm text-base-content/70">
          {gettext("Prices are net; the shop shows them with %{rate} % VAT.",
            rate: Format.percent(@product.tax_class.rate)
          )}
        </p>
        <button
          type="button"
          phx-click="new_variant"
          phx-target={@myself}
          class="btn btn-primary btn-sm"
          id="new-variant"
        >
          <.icon name="hero-plus" class="size-4" /> {gettext("New variant")}
        </button>
      </div>

      <div
        id="variant-list"
        phx-hook="Sortable"
        phx-target={@myself}
        data-event="reorder"
        class="space-y-3"
      >
        <div data-sortable-list class="space-y-3">
          <section
            :for={variant <- @product.variants}
            data-id={variant.id}
            id={"variant-#{variant.id}"}
            class="card bg-base-100 shadow-sm"
          >
            <div class="card-body gap-3 p-4">
              <div class="flex flex-wrap items-center gap-3">
                <span
                  data-sortable-handle
                  class="cursor-grab text-base-content/40"
                  title={gettext("Drag")}
                >
                  <.icon name="hero-bars-2" class="size-5" />
                </span>
                <span class="font-mono text-sm">{variant.number}</span>
                <span class="font-medium">{Translated.t(variant.name, @locale)}</span>
                <span class="badge badge-ghost badge-sm">{Unit.label(variant.unit)}</span>
                <span :if={!variant.active} class="badge badge-warning badge-sm">{gettext("inactive")}</span>
                <span class="text-sm text-base-content/70">
                  {stock_label(variant, @locale)} · {Translated.t(variant.delivery_time, @locale)}
                </span>
                <div class="ml-auto flex gap-1">
                  <button
                    type="button"
                    phx-click="edit_variant"
                    phx-value-id={variant.id}
                    phx-target={@myself}
                    class="btn btn-ghost btn-xs"
                    id={"edit-variant-#{variant.id}"}
                  >
                    <.icon name="hero-pencil-square" class="size-4" /> {gettext("Edit")}
                  </button>
                  <button
                    type="button"
                    phx-click="delete_variant"
                    phx-value-id={variant.id}
                    phx-target={@myself}
                    data-confirm={gettext("Delete this variant and its prices?")}
                    class="btn btn-ghost btn-xs text-error"
                    id={"delete-variant-#{variant.id}"}
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </div>

              <table class="table table-sm" id={"prices-#{variant.id}"}>
                <thead>
                  <tr>
                    <th>{gettext("from quantity")}</th>
                    <th class="text-right">{gettext("net")}</th>
                    <th class="text-right">{gettext("gross")}</th>
                    <th>{gettext("valid")}</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={price <- variant.prices} id={"price-#{price.id}"}>
                    <td>
                      {Format.quantity(price.min_quantity, variant.unit, @locale)} {Unit.symbol(
                        variant.unit
                      )}
                    </td>
                    <td class="text-right">{Format.money(price.amount, @locale)}</td>
                    <td class="text-right">{Format.money(gross(price.amount, @product), @locale)}</td>
                    <td>
                      <span :if={price.promotion} class="badge badge-error badge-sm">{gettext("Sale")}</span>
                      {validity(price)}
                    </td>
                    <td class="text-right">
                      <button
                        type="button"
                        phx-click="delete_price"
                        phx-value-id={price.id}
                        phx-target={@myself}
                        class="btn btn-ghost btn-xs text-error"
                        id={"delete-price-#{price.id}"}
                      >
                        <.icon name="hero-trash" class="size-4" />
                      </button>
                    </td>
                  </tr>
                  <tr :if={variant.prices == []}>
                    <td colspan="5" class="text-base-content/60">{gettext("No price yet.")}</td>
                  </tr>
                </tbody>
              </table>
              <div>
                <button
                  type="button"
                  phx-click="new_price"
                  phx-value-variant={variant.id}
                  phx-target={@myself}
                  class="btn btn-ghost btn-xs"
                  id={"new-price-#{variant.id}"}
                >
                  <.icon name="hero-plus" class="size-4" /> {gettext("Add price")}
                </button>
              </div>
            </div>
          </section>
        </div>
      </div>

      <.variant_modal :if={@variant_form} form={@variant_form} myself={@myself} />
      <.price_modal :if={@price_form} form={@price_form} myself={@myself} />
    </div>
    """
  end

  attr :form, :any, required: true
  attr :myself, :any, required: true

  defp variant_modal(assigns) do
    ~H"""
    <div class="modal modal-open" id="variant-modal">
      <div class="modal-box max-w-2xl">
        <h2 class="text-xl font-bold">{gettext("Variant")}</h2>
        <.form
          for={@form}
          id="variant-form"
          phx-change="validate_variant"
          phx-submit="save_variant"
          phx-target={@myself}
          class="mt-4"
        >
          <div class="grid gap-3 sm:grid-cols-2">
            <.input field={@form[:number]} label={gettext("Article no.")} />
            <.input
              field={@form[:unit]}
              type="select"
              label={gettext("Unit")}
              options={Enum.map(Unit.values(), &{Unit.label(&1), &1})}
            />
          </div>
          <.translated_input field={@form[:name]} label={gettext("Name")} />
          <div class="grid gap-3 sm:grid-cols-2">
            <.input
              field={@form[:stock]}
              type="number"
              step="any"
              label={gettext("Stock (empty = made to order)")}
            />
            <.input field={@form[:weight_kg]} type="number" step="any" label={gettext("Weight (kg)")} />
          </div>
          <.translated_input field={@form[:delivery_time]} label={gettext("Delivery time")} />
          <.input field={@form[:active]} type="checkbox" label={gettext("Active")} />
          <div class="modal-action">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
              "Cancel"
            )}</button>
            <button type="submit" class="btn btn-primary" id="save-variant">{gettext("Save")}</button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :myself, :any, required: true

  defp price_modal(assigns) do
    ~H"""
    <div class="modal modal-open" id="price-modal">
      <div class="modal-box">
        <h2 class="text-xl font-bold">{gettext("Add price")}</h2>
        <.form
          for={@form}
          id="price-form"
          phx-change="validate_price"
          phx-submit="save_price"
          phx-target={@myself}
          class="mt-4"
        >
          <div class="grid gap-3 sm:grid-cols-2">
            <.input
              field={@form[:amount]}
              type="number"
              step="any"
              label={gettext("Net price per unit")}
            />
            <.input
              field={@form[:min_quantity]}
              type="number"
              step="any"
              label={gettext("From quantity")}
            />
            <.input field={@form[:valid_from]} type="date" label={gettext("Valid from")} />
            <.input field={@form[:valid_until]} type="date" label={gettext("Valid until")} />
          </div>
          <.input
            field={@form[:promotion]}
            type="checkbox"
            label={gettext("Promotion price (regular price is shown crossed out)")}
          />
          <div class="modal-action">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
              "Cancel"
            )}</button>
            <button type="submit" class="btn btn-primary" id="save-price">{gettext("Save")}</button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp gross(net, product) do
    net
    |> Decimal.mult(Decimal.add(100, product.tax_class.rate))
    |> Decimal.div(100)
    |> Decimal.round(2)
  end

  defp stock_label(%{stock: nil}, _locale), do: gettext("made to order")

  defp stock_label(variant, locale),
    do: gettext("%{stock} in stock", stock: Format.quantity(variant.stock, variant.unit, locale))

  defp validity(%{valid_from: nil, valid_until: nil}), do: gettext("always")

  defp validity(%{valid_from: from, valid_until: nil}),
    do: gettext("from %{date}", date: Format.date(from))

  defp validity(%{valid_from: nil, valid_until: until}),
    do: gettext("until %{date}", date: Format.date(until))

  defp validity(%{valid_from: from, valid_until: until}),
    do: "#{Format.date(from)} – #{Format.date(until)}"
end
