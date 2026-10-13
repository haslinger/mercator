defmodule MercatorWeb.Admin.ProductPropertiesTab do
  @moduledoc """
  Product editor tab "properties" (back office step 4d): the product's
  property values grouped by property group; add a value for an existing
  or a new property, change and remove values.
  """
  use MercatorWeb, :live_component

  alias Mercator.Catalog
  alias Mercator.Catalog.Listing
  alias Mercator.Translated

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:adding, fn -> false end)
     |> assign_new(:editing, fn -> nil end)
     |> assign_new(:error, fn -> nil end)
     |> load()}
  end

  defp load(socket) do
    actor = socket.assigns.current_user

    product =
      Catalog.get_product!(socket.assigns.product_id,
        actor: actor,
        load: [product_properties: [property: :property_group]]
      )

    socket
    |> assign(:product, product)
    |> assign(
      :groups,
      Catalog.list_property_groups!(
        actor: actor,
        load: :properties,
        query: [sort: [position: :asc]]
      )
    )
  end

  # --- events ---

  @impl true
  def handle_event("add", _params, socket),
    do: {:noreply, assign(socket, adding: true, editing: nil, error: nil)}

  def handle_event("cancel", _params, socket),
    do: {:noreply, assign(socket, adding: false, editing: nil, error: nil)}

  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       editing: Enum.find(socket.assigns.product.product_properties, &(&1.id == id)),
       adding: false
     )}
  end

  def handle_event("save_new", params, socket) do
    actor = socket.assigns.current_user

    with {:ok, property} <- property_for(params, socket),
         {:ok, _value} <-
           Catalog.set_product_property(
             Map.merge(
               %{product_id: socket.assigns.product.id, property_id: property.id},
               value_attrs(property, params)
             ),
             actor: actor
           ) do
      {:noreply, socket |> assign(adding: false, error: nil) |> load()}
    else
      {:error, _} ->
        {:noreply, assign(socket, :error, gettext("Please check the property and its value."))}
    end
  end

  def handle_event("save_value", params, socket) do
    value = socket.assigns.editing

    case Catalog.update_product_property(value, value_attrs(value.property, params),
           actor: socket.assigns.current_user
         ) do
      {:ok, _} -> {:noreply, socket |> assign(editing: nil, error: nil) |> load()}
      {:error, _} -> {:noreply, assign(socket, :error, gettext("Please check the value."))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    value = Enum.find(socket.assigns.product.product_properties, &(&1.id == id))
    Catalog.destroy_product_property!(value, actor: socket.assigns.current_user)
    {:noreply, load(socket)}
  end

  # an existing property, or a new one created from the form
  defp property_for(%{"property_id" => id}, socket) when id not in [nil, ""] do
    case Enum.find(Enum.flat_map(socket.assigns.groups, & &1.properties), &(&1.id == id)) do
      nil -> {:error, :not_found}
      property -> {:ok, property}
    end
  end

  defp property_for(%{"new_property" => attrs}, socket) do
    Catalog.create_property(
      %{
        name: attrs["name"],
        kind: attrs["kind"],
        unit: attrs["unit"],
        property_group_id: attrs["property_group_id"],
        position: 100
      },
      actor: socket.assigns.current_user
    )
  end

  defp property_for(_params, _socket), do: {:error, :missing}

  defp value_attrs(%{kind: :text}, params), do: %{text_value: params["text_value"]}

  defp value_attrs(%{kind: :number}, params),
    do: %{number_value: blank_to_nil(params["number_value"])}

  defp value_attrs(%{kind: :boolean}, params),
    do: %{boolean_value: params["boolean_value"] == "true"}

  defp value_attrs(%{kind: kind}, params) when is_binary(kind),
    do: value_attrs(%{kind: String.to_existing_atom(kind)}, params)

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp grouped(product) do
    product.product_properties
    |> Enum.group_by(& &1.property.property_group)
    |> Enum.sort_by(fn {group, _} -> group.position end)
    |> Enum.map(fn {group, values} -> {group, Enum.sort_by(values, & &1.property.position)} end)
  end

  defp unused_properties(groups, product) do
    used = MapSet.new(product.product_properties, & &1.property_id)

    for group <- groups,
        property <- group.properties,
        not MapSet.member?(used, property.id),
        do: {group, property}
  end

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <div class="flex justify-end">
        <button
          type="button"
          phx-click="add"
          phx-target={@myself}
          class="btn btn-primary btn-sm"
          id="add-property"
        >
          <.icon name="hero-plus" class="size-4" /> {gettext("Add property")}
        </button>
      </div>

      <p :if={@product.product_properties == []} class="text-base-content/60" id="no-properties">
        {gettext("No properties yet.")}
      </p>

      <div
        :if={@product.product_properties != []}
        class="overflow-x-auto rounded-box bg-base-100 shadow-sm"
      >
        <table class="table" id="properties-table">
          <tbody :for={{group, values} <- grouped(@product)}>
            <tr class="bg-base-200">
              <th colspan="3">{Translated.t(group.name, @locale)}</th>
            </tr>
            <tr :for={value <- values} id={"property-value-#{value.id}"}>
              <td class="w-1/3">
                {Translated.t(value.property.name, @locale)}
                <span
                  :if={value.property.filterable}
                  class="badge badge-ghost badge-xs"
                  title={gettext("Shown as filter on category pages")}
                >
                  {gettext("Filter")}
                </span>
              </td>
              <td>{Listing.value_label(value, @locale)}</td>
              <td class="text-right whitespace-nowrap">
                <button
                  type="button"
                  phx-click="edit"
                  phx-value-id={value.id}
                  phx-target={@myself}
                  class="btn btn-ghost btn-xs"
                  id={"edit-property-#{value.id}"}
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </button>
                <button
                  type="button"
                  phx-click="delete"
                  phx-value-id={value.id}
                  phx-target={@myself}
                  class="btn btn-ghost btn-xs text-error"
                  id={"delete-property-#{value.id}"}
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@adding} class="modal modal-open" id="add-property-modal">
        <div class="modal-box max-w-xl">
          <h2 class="text-xl font-bold">{gettext("Add property")}</h2>
          <p :if={@error} class="alert alert-error mt-2">{@error}</p>
          <form
            id="add-property-form"
            phx-submit="save_new"
            phx-target={@myself}
            class="mt-4 space-y-3"
          >
            <fieldset class="fieldset">
              <legend class="fieldset-legend">{gettext("Existing property")}</legend>
              <select name="property_id" class="select w-full" id="property-select">
                <option value="">{gettext("– or create a new one below –")}</option>
                <option
                  :for={{group, property} <- unused_properties(@groups, @product)}
                  value={property.id}
                >
                  {Translated.t(group.name, @locale)}: {Translated.t(property.name, @locale)} ({kind_label(
                    property.kind
                  )})
                </option>
              </select>
            </fieldset>

            <details class="collapse-arrow collapse bg-base-200" id="new-property">
              <summary class="collapse-title text-sm font-medium">{gettext("New property")}</summary>
              <div class="collapse-content space-y-2">
                <div class="grid gap-2 sm:grid-cols-2">
                  <input
                    name="new_property[name][de]"
                    placeholder={gettext("Name (DE)")}
                    class="input w-full"
                  />
                  <input
                    name="new_property[name][en]"
                    placeholder={gettext("Name (EN)")}
                    class="input w-full"
                  />
                  <select name="new_property[kind]" class="select w-full">
                    <option :for={kind <- [:text, :number, :boolean]} value={kind}>
                      {kind_label(kind)}
                    </option>
                  </select>
                  <input
                    name="new_property[unit]"
                    placeholder={gettext("Unit, e.g. mm")}
                    class="input w-full"
                  />
                </div>
                <select name="new_property[property_group_id]" class="select w-full">
                  <option :for={group <- @groups} value={group.id}>
                    {Translated.t(group.name, @locale)}
                  </option>
                </select>
              </div>
            </details>

            <.value_inputs kind={nil} value={nil} />

            <div class="modal-action">
              <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
                "Cancel"
              )}</button>
              <button type="submit" class="btn btn-primary" id="save-new-property">{gettext("Add")}</button>
            </div>
          </form>
        </div>
      </div>

      <div :if={@editing} class="modal modal-open" id="edit-property-modal">
        <div class="modal-box max-w-xl">
          <h2 class="text-xl font-bold">{Translated.t(@editing.property.name, @locale)}</h2>
          <p :if={@error} class="alert alert-error mt-2">{@error}</p>
          <form
            id="edit-property-form"
            phx-submit="save_value"
            phx-target={@myself}
            class="mt-4 space-y-3"
          >
            <.value_inputs kind={@editing.property.kind} value={@editing} />
            <div class="modal-action">
              <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
                "Cancel"
              )}</button>
              <button type="submit" class="btn btn-primary" id="save-property-value">{gettext("Save")}</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :kind, :atom,
    required: true,
    doc: "nil shows the inputs for all kinds (property not chosen yet)"

  attr :value, :any, required: true

  defp value_inputs(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <legend class="fieldset-legend">{gettext("Value")}</legend>
      <div :if={@kind in [nil, :text]} class="grid gap-2 sm:grid-cols-2">
        <input
          :for={locale <- Translated.locales()}
          name={"text_value[#{locale}]"}
          value={@value && @value.text_value && @value.text_value[locale]}
          placeholder={gettext("Text") <> " (#{String.upcase(locale)})"}
          class="input w-full"
          id={"value-text-#{locale}"}
        />
      </div>
      <input
        :if={@kind in [nil, :number]}
        type="number"
        step="any"
        name="number_value"
        value={@value && @value.number_value && Decimal.to_string(@value.number_value, :normal)}
        placeholder={gettext("Number")}
        class="input w-full"
        id="value-number"
      />
      <label :if={@kind in [nil, :boolean]} class="label text-base-content">
        <input
          type="checkbox"
          name="boolean_value"
          value="true"
          checked={@value && @value.boolean_value}
          class="checkbox checkbox-sm"
          id="value-boolean"
        />
        {gettext("Yes")}
      </label>
      <p :if={is_nil(@kind)} class="text-xs text-base-content/60">
        {gettext("Fill in the field that matches the kind of the property.")}
      </p>
    </fieldset>
    """
  end

  defp kind_label(:text), do: gettext("Text")
  defp kind_label(:number), do: gettext("Number")
  defp kind_label(:boolean), do: gettext("Yes/no")
end
