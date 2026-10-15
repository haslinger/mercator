defmodule MercatorWeb.Admin.TaxClassLive do
  @moduledoc """
  Tax classes (back office step 5, administrators only): list, create,
  edit (name, rate) and delete unused classes (#51).
  """
  use MercatorWeb, :live_view

  import MercatorWeb.TranslatedComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.TaxClass
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, {:require_role, :administrator}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: gettext("Tax classes"), form: nil) |> load()}
  end

  defp load(socket) do
    tax_classes =
      Catalog.list_tax_classes!(
        actor: socket.assigns.current_user,
        load: :product_count,
        query: [sort: [position: :asc]]
      )

    assign(socket, :tax_classes, tax_classes)
  end

  @impl true
  def handle_event("new", _params, socket) do
    form =
      TaxClass
      |> AshPhoenix.Form.for_create(:create, actor: socket.assigns.current_user)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    tax_class = Enum.find(socket.assigns.tax_classes, &(&1.id == id))

    form =
      tax_class
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
         socket |> assign(:form, nil) |> put_flash(:info, gettext("Tax class saved.")) |> load()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    tax_class = Enum.find(socket.assigns.tax_classes, &(&1.id == id))

    if tax_class.product_count > 0 do
      {:noreply, put_flash(socket, :error, gettext("This tax class is still used by products."))}
    else
      Catalog.destroy_tax_class!(tax_class, actor: socket.assigns.current_user)
      {:noreply, socket |> put_flash(:info, gettext("Tax class deleted.")) |> load()}
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
      active="tax-classes"
    >
      <div class="flex items-center justify-between">
        <h1 class="text-3xl font-bold">{gettext("Tax classes")}</h1>
        <button type="button" phx-click="new" class="btn btn-primary" id="new-tax-class">
          <.icon name="hero-plus" class="size-5" /> {gettext("New tax class")}
        </button>
      </div>

      <div class="overflow-x-auto rounded-box bg-base-100 shadow-sm">
        <table class="table" id="tax-classes">
          <thead>
            <tr>
              <th>{gettext("Name")}</th>
              <th>{gettext("Key")}</th>
              <th class="text-right">{gettext("Rate")}</th>
              <th class="text-right">{gettext("Products")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={tax_class <- @tax_classes} id={"tax-class-#{tax_class.id}"}>
              <td>{Translated.t(tax_class.name, @locale)}</td>
              <td class="font-mono text-sm">{tax_class.key}</td>
              <td class="text-right">{Format.percent(tax_class.rate)} %</td>
              <td class="text-right">{tax_class.product_count}</td>
              <td class="text-right whitespace-nowrap">
                <button
                  type="button"
                  phx-click="edit"
                  phx-value-id={tax_class.id}
                  class="btn btn-ghost btn-xs"
                  id={"edit-tax-class-#{tax_class.id}"}
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </button>
                <button
                  type="button"
                  phx-click="delete"
                  phx-value-id={tax_class.id}
                  data-confirm={gettext("Delete this tax class?")}
                  class="btn btn-ghost btn-xs text-error"
                  id={"delete-tax-class-#{tax_class.id}"}
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="text-sm text-base-content/70">
        {gettext(
          "Changing a rate affects the gross prices of all products in that class immediately."
        )}
      </p>

      <div :if={@form} class="modal modal-open" id="tax-class-modal">
        <div class="modal-box">
          <h2 class="text-xl font-bold">{gettext("Tax class")}</h2>
          <.form for={@form} id="tax-class-form" phx-change="validate" phx-submit="save" class="mt-4">
            <.input
              :if={@form.source.type == :create}
              field={@form[:key]}
              label={gettext("Key (e.g. reduced)")}
            />
            <.translated_input field={@form[:name]} label={gettext("Name")} />
            <div class="grid gap-3 sm:grid-cols-2">
              <.input field={@form[:rate]} type="number" step="any" label={gettext("Rate in %")} />
              <.input field={@form[:position]} type="number" label={gettext("Position")} />
            </div>
            <div class="modal-action">
              <button type="button" phx-click="cancel" class="btn btn-ghost">{gettext("Cancel")}</button>
              <button type="submit" class="btn btn-primary" id="save-tax-class">{gettext("Save")}</button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
