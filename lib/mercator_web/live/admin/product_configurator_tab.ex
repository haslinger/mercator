defmodule MercatorWeb.Admin.ProductConfiguratorTab do
  @moduledoc """
  Product editor tab "configurator" for configurable products (back office
  step 4f, #55): price settings, options (sortable by drag & drop) with
  their choices, and a preview of the default configuration's price.
  """
  use MercatorWeb, :live_component

  import MercatorWeb.TranslatedComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.{OptionChoice, ProductOption, Unit}
  alias Mercator.Translated
  alias MercatorWeb.Admin.ProductIndexLive
  alias MercatorWeb.Format

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:option_form, fn -> nil end)
     |> assign_new(:choice_form, fn -> nil end)
     |> load()}
  end

  defp load(socket) do
    product =
      Catalog.get_product!(socket.assigns.product_id,
        actor: socket.assigns.current_user,
        load: [:tax_class, options: :choices]
      )

    settings =
      product
      |> AshPhoenix.Form.for_update(:update, actor: socket.assigns.current_user, as: "settings")
      |> to_form()

    socket
    |> assign(:product, product)
    |> assign(:settings, settings)
    |> assign(:preview, Catalog.quote(product, %{}))
  end

  # --- price settings ---

  @impl true
  def handle_event("save_settings", %{"settings" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.settings, params: params) do
      {:ok, _} -> {:noreply, load(socket)}
      {:error, form} -> {:noreply, assign(socket, :settings, form)}
    end
  end

  # --- options ---

  def handle_event("new_option", _params, socket) do
    product = socket.assigns.product
    position = length(product.options) + 1

    form =
      ProductOption
      |> AshPhoenix.Form.for_create(:create,
        actor: socket.assigns.current_user,
        params: %{"kind" => "choice", "role" => "surcharge"},
        transform_params: fn _form, params, _ ->
          Map.merge(params, %{"product_id" => product.id, "position" => position})
        end
      )
      |> to_form()

    {:noreply, assign(socket, option_form: form, choice_form: nil)}
  end

  def handle_event("edit_option", %{"id" => id}, socket) do
    form =
      socket
      |> option(id)
      |> AshPhoenix.Form.for_update(:update, actor: socket.assigns.current_user)
      |> to_form()

    {:noreply, assign(socket, option_form: form, choice_form: nil)}
  end

  def handle_event("validate_option", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :option_form, AshPhoenix.Form.validate(socket.assigns.option_form, params))}
  end

  def handle_event("save_option", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.option_form, params: params) do
      {:ok, _} -> {:noreply, socket |> assign(:option_form, nil) |> load()}
      {:error, form} -> {:noreply, assign(socket, :option_form, form)}
    end
  end

  def handle_event("delete_option", %{"id" => id}, socket) do
    Catalog.destroy_product_option!(option(socket, id), actor: socket.assigns.current_user)
    {:noreply, load(socket)}
  end

  def handle_event("reorder", %{"id" => id, "index" => index}, socket) do
    options = socket.assigns.product.options

    options
    |> Enum.reject(&(&1.id == id))
    |> List.insert_at(index, option(socket, id))
    |> Enum.with_index(1)
    |> Enum.each(fn {option, position} ->
      if option.position != position,
        do:
          Catalog.update_product_option!(option, %{position: position},
            actor: socket.assigns.current_user
          )
    end)

    {:noreply, load(socket)}
  end

  # --- choices ---

  def handle_event("new_choice", %{"option" => option_id}, socket) do
    position = length(option(socket, option_id).choices) + 1

    form =
      OptionChoice
      |> AshPhoenix.Form.for_create(:create,
        actor: socket.assigns.current_user,
        transform_params: fn _form, params, _ ->
          Map.merge(params, %{"option_id" => option_id, "position" => position})
        end
      )
      |> to_form()

    {:noreply,
     assign(socket, choice_form: form, choice_option: option(socket, option_id), option_form: nil)}
  end

  def handle_event("edit_choice", %{"id" => id}, socket) do
    choice =
      socket.assigns.product.options |> Enum.flat_map(& &1.choices) |> Enum.find(&(&1.id == id))

    form =
      choice
      |> AshPhoenix.Form.for_update(:update, actor: socket.assigns.current_user)
      |> to_form()

    {:noreply,
     assign(socket,
       choice_form: form,
       choice_option: option(socket, choice.option_id),
       option_form: nil
     )}
  end

  def handle_event("validate_choice", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :choice_form, AshPhoenix.Form.validate(socket.assigns.choice_form, params))}
  end

  def handle_event("save_choice", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.choice_form, params: params) do
      {:ok, _} -> {:noreply, socket |> assign(:choice_form, nil) |> load()}
      {:error, form} -> {:noreply, assign(socket, :choice_form, form)}
    end
  end

  def handle_event("delete_choice", %{"id" => id}, socket) do
    choice =
      socket.assigns.product.options |> Enum.flat_map(& &1.choices) |> Enum.find(&(&1.id == id))

    Catalog.destroy_option_choice!(choice, actor: socket.assigns.current_user)
    {:noreply, load(socket)}
  end

  def handle_event("cancel", _params, socket),
    do: {:noreply, assign(socket, option_form: nil, choice_form: nil)}

  defp option(socket, id), do: Enum.find(socket.assigns.product.options, &(&1.id == id))

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <div class="grid gap-4 lg:grid-cols-3">
        <section class="card bg-base-100 shadow-sm lg:col-span-2">
          <div class="card-body">
            <h2 class="card-title">{gettext("Price calculation")}</h2>
            <.form for={@settings} id="settings-form" phx-submit="save_settings" phx-target={@myself}>
              <div class="grid gap-3 sm:grid-cols-2">
                <.input
                  field={@settings[:pricing]}
                  type="select"
                  label={gettext("Pricing")}
                  options={
                    Enum.map(ProductIndexLive.pricings(), fn {value, label} -> {label, value} end)
                  }
                />
                <.input
                  field={@settings[:rounding_mm]}
                  type="number"
                  label={gettext("Round dimensions up to (mm)")}
                />
                <.input
                  field={@settings[:min_billing_quantity]}
                  type="number"
                  step="any"
                  label={gettext("Minimum billed quantity (m³, m², lfm or pieces)")}
                />
                <.input
                  field={@settings[:min_order_value]}
                  type="number"
                  step="any"
                  label={gettext("Minimum order value (net)")}
                />
                <.input
                  field={@settings[:cutting_fee]}
                  type="number"
                  step="any"
                  label={gettext("Cutting fee per piece (net)")}
                />
              </div>
              <button type="submit" class="btn btn-primary btn-sm mt-3" id="save-settings">{gettext(
                "Save"
              )}</button>
            </.form>
          </div>
        </section>

        <section class="card bg-base-100 shadow-sm" id="preview">
          <div class="card-body">
            <h2 class="card-title">{gettext("Default configuration")}</h2>
            <%= case @preview do %>
              <% {:ok, quote} -> %>
                <p class="text-3xl font-bold" id="preview-gross">
                  {Format.money(quote.gross, @locale)}
                </p>
                <p class="text-sm text-base-content/70">
                  {gettext("net %{net}, %{measure} %{unit} per piece",
                    net: Format.money(quote.net, @locale),
                    measure: Format.quantity(quote.measure, quote.measure_unit, @locale),
                    unit: Unit.symbol(quote.measure_unit)
                  )}
                </p>
              <% {:error, errors} -> %>
                <p class="text-sm text-error" id="preview-errors">
                  {gettext("Not calculable yet:")}
                  {Enum.map_join(errors, ", ", fn {key, message} -> "#{key}: #{message}" end)}
                </p>
            <% end %>
          </div>
        </section>
      </div>

      <div class="flex items-center justify-between">
        <h2 class="text-xl font-bold">{gettext("Options")}</h2>
        <button
          type="button"
          phx-click="new_option"
          phx-target={@myself}
          class="btn btn-primary btn-sm"
          id="new-option"
        >
          <.icon name="hero-plus" class="size-4" /> {gettext("New option")}
        </button>
      </div>

      <div id="option-list" phx-hook="Sortable" phx-target={@myself} data-event="reorder">
        <div data-sortable-list class="space-y-3">
          <section
            :for={option <- @product.options}
            data-id={option.id}
            id={"option-#{option.id}"}
            class="card bg-base-100 shadow-sm"
          >
            <div class="card-body gap-2 p-4">
              <div class="flex flex-wrap items-center gap-2">
                <span
                  data-sortable-handle
                  class="cursor-grab text-base-content/40"
                  title={gettext("Drag")}
                >
                  <.icon name="hero-bars-2" class="size-5" />
                </span>
                <span class="font-medium">{Translated.t(option.name, @locale)}</span>
                <span class="font-mono text-xs text-base-content/50">{option.key}</span>
                <span class="badge badge-ghost badge-sm">{role_label(option.role)}</span>
                <span :if={option.kind == :number} class="text-sm text-base-content/70">
                  {number_range(option)}
                </span>
                <div class="ml-auto flex gap-1">
                  <button
                    type="button"
                    phx-click="edit_option"
                    phx-value-id={option.id}
                    phx-target={@myself}
                    class="btn btn-ghost btn-xs"
                    id={"edit-option-#{option.id}"}
                  >
                    <.icon name="hero-pencil-square" class="size-4" />
                  </button>
                  <button
                    type="button"
                    phx-click="delete_option"
                    phx-value-id={option.id}
                    phx-target={@myself}
                    data-confirm={gettext("Delete this option and its choices?")}
                    class="btn btn-ghost btn-xs text-error"
                    id={"delete-option-#{option.id}"}
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </div>

              <table :if={option.kind == :choice} class="table table-sm" id={"choices-#{option.id}"}>
                <tbody>
                  <tr :for={choice <- option.choices} id={"choice-#{choice.id}"}>
                    <td>
                      {Translated.t(choice.name, @locale)}
                      <span :if={choice.default} class="badge badge-primary badge-xs">{gettext(
                        "default"
                      )}</span>
                    </td>
                    <td class="text-right">{choice_effect(choice, option, @product, @locale)}</td>
                    <td class="text-right whitespace-nowrap">
                      <button
                        type="button"
                        phx-click="edit_choice"
                        phx-value-id={choice.id}
                        phx-target={@myself}
                        class="btn btn-ghost btn-xs"
                        id={"edit-choice-#{choice.id}"}
                      >
                        <.icon name="hero-pencil-square" class="size-4" />
                      </button>
                      <button
                        type="button"
                        phx-click="delete_choice"
                        phx-value-id={choice.id}
                        phx-target={@myself}
                        class="btn btn-ghost btn-xs text-error"
                        id={"delete-choice-#{choice.id}"}
                      >
                        <.icon name="hero-trash" class="size-4" />
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
              <div :if={option.kind == :choice}>
                <button
                  type="button"
                  phx-click="new_choice"
                  phx-value-option={option.id}
                  phx-target={@myself}
                  class="btn btn-ghost btn-xs"
                  id={"new-choice-#{option.id}"}
                >
                  <.icon name="hero-plus" class="size-4" /> {gettext("Add choice")}
                </button>
              </div>
            </div>
          </section>
        </div>
      </div>

      <.option_modal :if={@option_form} form={@option_form} myself={@myself} />
      <.choice_modal :if={@choice_form} form={@choice_form} option={@choice_option} myself={@myself} />
    </div>
    """
  end

  attr :form, :any, required: true
  attr :myself, :any, required: true

  defp option_modal(assigns) do
    ~H"""
    <div class="modal modal-open" id="option-modal">
      <div class="modal-box max-w-2xl">
        <h2 class="text-xl font-bold">{gettext("Option")}</h2>
        <.form
          for={@form}
          id="option-form"
          phx-change="validate_option"
          phx-submit="save_option"
          phx-target={@myself}
          class="mt-4"
        >
          <.translated_input field={@form[:name]} label={gettext("Name")} />
          <div class="grid gap-3 sm:grid-cols-2">
            <.input
              :if={@form.source.type == :create}
              field={@form[:key]}
              label={gettext("Key (e.g. species, length)")}
            />
            <.input
              :if={@form.source.type == :create}
              field={@form[:kind]}
              type="select"
              label={gettext("Kind")}
              options={[{gettext("Choice"), :choice}, {gettext("Number"), :number}]}
            />
            <.input
              field={@form[:role]}
              type="select"
              label={gettext("Role in the price")}
              options={role_options()}
            />
            <.input field={@form[:unit]} label={gettext("Unit (numbers), e.g. mm")} />
            <.input field={@form[:min]} type="number" step="any" label={gettext("Minimum")} />
            <.input field={@form[:max]} type="number" step="any" label={gettext("Maximum")} />
            <.input field={@form[:step]} type="number" step="any" label={gettext("Step")} />
            <.input field={@form[:default]} type="number" step="any" label={gettext("Default value")} />
          </div>
          <div class="modal-action">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
              "Cancel"
            )}</button>
            <button type="submit" class="btn btn-primary" id="save-option">{gettext("Save")}</button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :option, :any, required: true
  attr :myself, :any, required: true

  defp choice_modal(assigns) do
    ~H"""
    <div class="modal modal-open" id="choice-modal">
      <div class="modal-box max-w-xl">
        <h2 class="text-xl font-bold">{gettext("Choice")}</h2>
        <.form
          for={@form}
          id="choice-form"
          phx-change="validate_choice"
          phx-submit="save_choice"
          phx-target={@myself}
          class="mt-4"
        >
          <.input
            :if={@form.source.type == :create}
            field={@form[:key]}
            label={gettext("Key (e.g. oak)")}
          />
          <.translated_input field={@form[:name]} label={gettext("Name")} />
          <div class="grid gap-3 sm:grid-cols-2">
            <.input
              :if={@option.role == :base_price}
              field={@form[:base_price]}
              type="number"
              step="any"
              label={gettext("Base price per unit (net)")}
            />
            <.input
              :if={@option.role != :base_price}
              field={@form[:surcharge_percent]}
              type="number"
              step="any"
              label={gettext("Surcharge in %")}
            />
            <.input
              :if={@option.role != :base_price}
              field={@form[:surcharge_amount]}
              type="number"
              step="any"
              label={gettext("Surcharge per piece (net)")}
            />
          </div>
          <.input field={@form[:default]} type="checkbox" label={gettext("Default choice")} />
          <div class="modal-action">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
              "Cancel"
            )}</button>
            <button type="submit" class="btn btn-primary" id="save-choice">{gettext("Save")}</button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp role_options do
    Enum.map(~w(base_price surcharge length width thickness info)a, &{role_label(&1), &1})
  end

  defp role_label(:base_price), do: gettext("Base price")
  defp role_label(:surcharge), do: gettext("Surcharge")
  defp role_label(:length), do: gettext("Length")
  defp role_label(:width), do: gettext("Width")
  defp role_label(:thickness), do: gettext("Thickness")
  defp role_label(:info), do: gettext("No effect on price")

  defp number_range(option) do
    [
      option.min && Decimal.to_string(option.min, :normal),
      "–",
      option.max && Decimal.to_string(option.max, :normal),
      option.unit,
      option.default && "(#{gettext("default")} #{Decimal.to_string(option.default, :normal)})"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp choice_effect(choice, %{role: :base_price}, product, locale) do
    unit = product.pricing |> unit_of() |> Unit.symbol()
    "#{Format.money(choice.base_price || Decimal.new(0), locale)}/#{unit} #{gettext("net")}"
  end

  defp choice_effect(choice, _option, _product, locale) do
    [
      choice.surcharge_percent && not Decimal.eq?(choice.surcharge_percent, 0) &&
        "+#{Format.percent(choice.surcharge_percent)} %",
      choice.surcharge_amount && not Decimal.eq?(choice.surcharge_amount, 0) &&
        "+#{Format.money(choice.surcharge_amount, locale)}"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  defp unit_of(:per_volume), do: :m3
  defp unit_of(:per_area), do: :m2
  defp unit_of(:per_length), do: :lfm
  defp unit_of(_), do: :piece
end
