defmodule MercatorWeb.Admin.CategoryTreeLive do
  @moduledoc """
  Category management (back office step 2): the category tree with drag &
  drop (moving and sorting), creating, editing, state changes and deleting.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.TranslatedComponents

  alias Mercator.Catalog
  alias Mercator.Translated

  on_mount {MercatorWeb.LiveUserAuth, {:require_any_role, [:productmanager, :administrator]}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, gettext("Categories")) |> load_tree()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, editing: nil)

  defp apply_action(socket, :new, params) do
    form =
      Catalog.form_to_create_category(
        actor: socket.assigns.current_user,
        params: %{"parent_id" => params["parent"]}
      )

    assign(socket, form: to_form(form), editing: nil, parent: find(socket, params["parent"]))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    category = find(socket, id)
    form = Catalog.form_to_update_category(category, actor: socket.assigns.current_user)
    assign(socket, form: to_form(form), editing: category, parent: nil)
  end

  defp load_tree(socket) do
    categories =
      Catalog.list_categories!(
        actor: socket.assigns.current_user,
        load: [:product_count, :child_count],
        query: [sort: [position: :asc, slug: :asc]]
      )

    assign(socket, categories: categories, tree: Enum.group_by(categories, & &1.parent_id))
  end

  defp find(_socket, nil), do: nil
  defp find(socket, id), do: Enum.find(socket.assigns.categories, &(&1.id == id))

  # --- events ---

  @impl true
  def handle_event("move", %{"id" => id, "parent_id" => parent_id, "index" => index}, socket) do
    category = find(socket, id)

    case Catalog.place_category(category, parent_id, index, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, load_tree(socket)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("A category cannot be moved below itself."))
         |> load_tree()}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Category saved."))
         |> load_tree()
         |> push_patch(to: ~p"/admin/categories")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("transition", %{"id" => id, "to" => to}, socket) do
    category = find(socket, id)
    actor = socket.assigns.current_user

    result =
      case to do
        "active" -> Catalog.activate_category(category, actor: actor)
        "hidden" -> Catalog.hide_category(category, actor: actor)
        "draft" -> Catalog.deactivate_category(category, actor: actor)
      end

    case result do
      {:ok, _} ->
        {:noreply, load_tree(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("This change is not possible."))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    category = find(socket, id)

    cond do
      category.child_count > 0 ->
        {:noreply, put_flash(socket, :error, gettext("Delete or move the subcategories first."))}

      category.product_count > 0 ->
        {:noreply,
         put_flash(socket, :error, gettext("Remove the products from this category first."))}

      true ->
        Catalog.destroy_category!(category, actor: socket.assigns.current_user)
        {:noreply, socket |> put_flash(:info, gettext("Category deleted.")) |> load_tree()}
    end
  end

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      locale={@locale}
      active="categories"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Categories")}</h1>
        <.link patch={~p"/admin/categories/new"} class="btn btn-primary" id="new-category">
          <.icon name="hero-plus" class="size-5" /> {gettext("New category")}
        </.link>
      </div>
      <p class="text-sm text-base-content/70">
        {gettext("Drag categories by the handle to sort them or to move them into another category.")}
      </p>

      <div
        id="category-tree"
        phx-hook="Sortable"
        data-event="move"
        class="rounded-box bg-base-100 p-4 shadow-sm"
      >
        <.tree_level tree={@tree} parent_id={nil} locale={@locale} />
      </div>

      <.category_form :if={@form} form={@form} editing={@editing} parent={@parent} locale={@locale} />
    </Layouts.admin>
    """
  end

  attr :tree, :map, required: true
  attr :parent_id, :any, required: true
  attr :locale, :string, required: true

  defp tree_level(assigns) do
    assigns = assign(assigns, :categories, Map.get(assigns.tree, assigns.parent_id, []))

    ~H"""
    <ul
      data-sortable-list
      data-group="categories"
      data-parent-id={@parent_id}
      class={["space-y-1", @parent_id && "ml-6 mt-1 border-l border-base-300 pl-2", "min-h-2"]}
    >
      <li :for={category <- @categories} data-id={category.id} id={"category-#{category.id}"}>
        <div class="flex items-center gap-2 rounded-box px-2 py-1 hover:bg-base-200">
          <span data-sortable-handle class="cursor-grab text-base-content/40" title={gettext("Drag")}>
            <.icon name="hero-bars-2" class="size-5" />
          </span>
          <span class="font-medium">{Translated.t(category.name, @locale)}</span>
          <span class="text-xs text-base-content/50">/{category.slug}</span>
          <.state_badge state={category.state} />
          <span class="text-xs text-base-content/60">
            {ngettext("1 product", "%{count} products", category.product_count)}
          </span>
          <div class="ml-auto flex items-center gap-1">
            <.state_actions category={category} />
            <.link
              patch={~p"/admin/categories/new?parent=#{category.id}"}
              class="btn btn-ghost btn-xs"
              title={gettext("Add subcategory")}
              id={"add-child-#{category.id}"}
            >
              <.icon name="hero-plus" class="size-4" />
            </.link>
            <.link
              patch={~p"/admin/categories/#{category.id}/edit"}
              class="btn btn-ghost btn-xs"
              title={gettext("Edit")}
              id={"edit-#{category.id}"}
            >
              <.icon name="hero-pencil-square" class="size-4" />
            </.link>
            <button
              type="button"
              phx-click="delete"
              phx-value-id={category.id}
              data-confirm={gettext("Delete this category?")}
              class="btn btn-ghost btn-xs text-error"
              title={gettext("Delete")}
              id={"delete-#{category.id}"}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>
        <.tree_level tree={@tree} parent_id={category.id} locale={@locale} />
      </li>
    </ul>
    """
  end

  attr :state, :atom, required: true

  defp state_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @state == :active && "badge-success",
      @state == :hidden && "badge-warning",
      @state == :draft && "badge-ghost"
    ]}>
      {state_label(@state)}
    </span>
    """
  end

  attr :category, :map, required: true

  defp state_actions(assigns) do
    ~H"""
    <button
      :for={{to, label} <- transitions(@category.state)}
      type="button"
      phx-click="transition"
      phx-value-id={@category.id}
      phx-value-to={to}
      class="btn btn-ghost btn-xs"
      id={"transition-#{@category.id}-#{to}"}
    >
      {label}
    </button>
    """
  end

  defp transitions(:draft), do: [{"active", gettext("Activate")}, {"hidden", gettext("Hide")}]
  defp transitions(:active), do: [{"hidden", gettext("Hide")}, {"draft", gettext("Draft")}]
  defp transitions(:hidden), do: [{"active", gettext("Activate")}, {"draft", gettext("Draft")}]

  defp state_label(:draft), do: gettext("Draft")
  defp state_label(:active), do: gettext("Active")
  defp state_label(:hidden), do: gettext("Hidden")

  attr :form, :any, required: true
  attr :editing, :any, required: true
  attr :parent, :any, required: true
  attr :locale, :string, required: true

  defp category_form(assigns) do
    ~H"""
    <div class="modal modal-open" id="category-modal">
      <div class="modal-box max-w-2xl">
        <h2 class="text-xl font-bold">
          <%= cond do %>
            <% @editing -> %>
              {gettext("Edit category")}
            <% @parent -> %>
              {gettext("New subcategory of %{parent}", parent: Translated.t(@parent.name, @locale))}
            <% true -> %>
              {gettext("New category")}
          <% end %>
        </h2>
        <.form for={@form} id="category-form" phx-change="validate" phx-submit="save" class="mt-4">
          <input
            :if={!@editing}
            type="hidden"
            name={@form[:parent_id].name}
            value={@form[:parent_id].value}
          />
          <.translated_input field={@form[:name]} label={gettext("Name")} />
          <.translated_input
            field={@form[:description]}
            label={gettext("Short description")}
            type="textarea"
            rows="2"
          />
          <.translated_input
            field={@form[:long_description]}
            label={gettext("Text below the products")}
            type="markdown"
          />
          <.input
            field={@form[:slug]}
            label={gettext("URL name (slug), generated from the German name if empty")}
          />
          <div class="modal-action">
            <.link patch={~p"/admin/categories"} class="btn btn-ghost" id="cancel-category">
              {gettext("Cancel")}
            </.link>
            <button type="submit" class="btn btn-primary" id="save-category">{gettext("Save")}</button>
          </div>
        </.form>
      </div>
      <.link patch={~p"/admin/categories"} class="modal-backdrop">{gettext("Close")}</.link>
    </div>
    """
  end
end
