defmodule MercatorWeb.Admin.PageTreeLive do
  @moduledoc """
  CMS pages in the back office (`/admin/pages`, CMS step 3): the page tree
  with drag & drop (moving and sorting), new pages and deleting drafts.
  Pages are edited in `MercatorWeb.Admin.PageEditLive`.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.TranslatedComponents
  import MercatorWeb.Admin.PageComponents

  alias Mercator.Content
  alias Mercator.Translated

  on_mount {MercatorWeb.LiveUserAuth, {:require_any_role, [:contentmanager, :administrator]}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, gettext("Pages")) |> load_tree()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, parent: nil)

  defp apply_action(socket, :new, params) do
    form =
      Content.form_to_create_page(
        actor: socket.assigns.current_user,
        params: %{"parent_id" => params["parent"]}
      )

    assign(socket, form: to_form(form), parent: find(socket, params["parent"]))
  end

  defp load_tree(socket) do
    pages =
      Content.list_pages!(
        actor: socket.assigns.current_user,
        query: [sort: [position: :asc, path: :asc]]
      )

    assign(socket, pages: pages, tree: Enum.group_by(pages, & &1.parent_id))
  end

  defp find(_socket, nil), do: nil
  defp find(socket, id), do: Enum.find(socket.assigns.pages, &(&1.id == id))

  @impl true
  def handle_event("move", %{"id" => id, "parent_id" => parent_id, "index" => index}, socket) do
    case Content.place_page(find(socket, id), parent_id, index, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, load_tree(socket)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("This move is not possible."))
         |> load_tree()}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("create", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, page} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Page created. Add blocks and publish it."))
         |> push_navigate(to: ~p"/admin/pages/#{page.id}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    page = find(socket, id)

    cond do
      Map.has_key?(socket.assigns.tree, page.id) ->
        {:noreply, put_flash(socket, :error, gettext("Delete or move the subpages first."))}

      page.state != :draft ->
        {:noreply,
         put_flash(socket, :error, gettext("Published pages cannot be deleted; archive them."))}

      true ->
        Content.destroy_page!(page, actor: socket.assigns.current_user)
        {:noreply, socket |> put_flash(:info, gettext("Page deleted.")) |> load_tree()}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="pages">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Pages")}</h1>
        <.link patch={~p"/admin/pages/new"} class="btn btn-primary" id="new-page">
          <.icon name="hero-plus" class="size-5" /> {gettext("New page")}
        </.link>
      </div>
      <p class="text-sm text-base-content/70">
        {gettext("Drag pages by the handle to sort them or to move them below another page.")}
      </p>

      <div
        id="page-tree"
        phx-hook="Sortable"
        data-event="move"
        class="rounded-box bg-base-100 p-4 shadow-sm"
      >
        <p :if={@pages == []} class="text-base-content/70" id="no-pages">
          {gettext("No pages yet.")}
        </p>
        <.tree_level tree={@tree} parent_id={nil} locale={@locale} />
      </div>

      <div :if={@form} class="modal modal-open" id="page-modal">
        <div class="modal-box">
          <h2 class="text-xl font-bold">
            <%= if @parent do %>
              {gettext("New subpage of %{parent}", parent: Translated.t(@parent.title, @locale))}
            <% else %>
              {gettext("New page")}
            <% end %>
          </h2>
          <.form for={@form} id="page-form" phx-change="validate" phx-submit="create" class="mt-4">
            <input type="hidden" name={@form[:parent_id].name} value={@form[:parent_id].value} />
            <.translated_input field={@form[:title]} label={gettext("Title")} />
            <.input
              field={@form[:slug]}
              label={gettext("URL name (slug), generated from the German title if empty")}
            />
            <div class="modal-action">
              <.link patch={~p"/admin/pages"} class="btn btn-ghost">{gettext("Cancel")}</.link>
              <button type="submit" class="btn btn-primary" id="create-page">{gettext("Create")}</button>
            </div>
          </.form>
        </div>
        <.link patch={~p"/admin/pages"} class="modal-backdrop">{gettext("Close")}</.link>
      </div>
    </Layouts.admin>
    """
  end

  attr :tree, :map, required: true
  attr :parent_id, :any, required: true
  attr :locale, :string, required: true

  defp tree_level(assigns) do
    assigns = assign(assigns, :pages, Map.get(assigns.tree, assigns.parent_id, []))

    ~H"""
    <ul
      data-sortable-list
      data-group="pages"
      data-parent-id={@parent_id}
      class={["space-y-1", @parent_id && "ml-6 mt-1 border-l border-base-300 pl-2", "min-h-2"]}
    >
      <li :for={page <- @pages} data-id={page.id} id={"page-#{page.id}"}>
        <div class="flex flex-wrap items-center gap-2 rounded-box px-2 py-1 hover:bg-base-200">
          <span data-sortable-handle class="cursor-grab text-base-content/40" title={gettext("Drag")}>
            <.icon name="hero-bars-2" class="size-5" />
          </span>
          <.link navigate={~p"/admin/pages/#{page.id}"} class="font-medium link link-hover">
            {Translated.t(page.title, @locale)}
          </.link>
          <span class="text-xs text-base-content/50">/pages/{page.path}</span>
          <.page_state_badge state={page.state} />
          <span :if={page.changes_pending} class="badge badge-sm badge-info badge-outline">
            {gettext("Unpublished changes")}
          </span>
          <span :if={page.menu != :none} class="badge badge-sm badge-ghost">
            {menu_label(page.menu)}
          </span>
          <div class="ml-auto flex items-center gap-1">
            <.link
              patch={~p"/admin/pages/new?parent=#{page.id}"}
              class="btn btn-ghost btn-xs"
              title={gettext("Add subpage")}
              id={"add-child-#{page.id}"}
            >
              <.icon name="hero-plus" class="size-4" />
            </.link>
            <.link
              navigate={~p"/admin/pages/#{page.id}"}
              class="btn btn-ghost btn-xs"
              title={gettext("Edit")}
              id={"edit-#{page.id}"}
            >
              <.icon name="hero-pencil-square" class="size-4" />
            </.link>
            <button
              :if={page.state == :draft}
              type="button"
              phx-click="delete"
              phx-value-id={page.id}
              data-confirm={gettext("Delete this page?")}
              class="btn btn-ghost btn-xs text-error"
              title={gettext("Delete")}
              id={"delete-#{page.id}"}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>
        <.tree_level tree={@tree} parent_id={page.id} locale={@locale} />
      </li>
    </ul>
    """
  end
end
