defmodule MercatorWeb.Admin.PageEditLive do
  @moduledoc """
  The editor of a CMS page (`/admin/pages/:id`, CMS step 3): the blocks of
  the working copy as they will look (add, edit one at a time, reorder by
  drag & drop, delete), the page settings, publishing (#90) and the
  history of published versions with restore (#84).

  Blocks are edited one at a time in a modal: the Markdown editor keeps its
  own DOM (`phx-update="ignore"`), so one big form with all blocks would
  get out of step when blocks are reordered.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.TranslatedComponents
  import MercatorWeb.ContentComponents, only: [block: 1]
  import MercatorWeb.Admin.PageComponents

  alias Ash.Resource.Info
  alias Mercator.Content
  alias Mercator.Content.Blocks
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, {:require_any_role, [:contentmanager, :administrator]}}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Content.get_page(id, actor: socket.assigns.current_user) do
      {:ok, page} ->
        {:ok,
         socket
         |> assign(:block_form, nil)
         |> assign(:editing_block, nil)
         |> assign_page(page)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Page not found."))
         |> push_navigate(to: ~p"/admin/pages")}
    end
  end

  defp assign_page(socket, page) do
    actor = socket.assigns.current_user

    versions =
      page
      |> Ash.load!(:paper_trail_versions, actor: actor)
      |> Map.fetch!(:paper_trail_versions)
      # only the name of whoever published is shown; staff may not read users
      |> Ash.load!(:user, authorize?: false)
      |> Enum.sort_by(& &1.version_inserted_at, {:desc, DateTime})

    socket
    |> assign(:page, page)
    |> assign(:page_title, Translated.t(page.title, socket.assigns.locale))
    |> assign(:versions, versions)
    |> assign(
      :settings_form,
      page |> Content.form_to_update_page(actor: actor, forms: [auto?: false]) |> to_form()
    )
  end

  # --- page settings and state ---

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.settings_form, settings_params(params))
    {:noreply, assign(socket, :settings_form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.settings_form, params: settings_params(params)) do
      {:ok, page} ->
        {:noreply, socket |> put_flash(:info, gettext("Page saved.")) |> assign_page(page)}

      {:error, form} ->
        {:noreply, assign(socket, :settings_form, form)}
    end
  end

  def handle_event("publish", _params, socket),
    do: run(socket, &Content.publish_page/2, gettext("Page published."))

  def handle_event("discard", _params, socket),
    do: run(socket, &Content.discard_page_changes/2, gettext("Changes discarded."))

  def handle_event("transition", %{"to" => "hidden"}, socket),
    do: run(socket, &Content.hide_page/2, gettext("Page hidden from the menus."))

  def handle_event("transition", %{"to" => "published"}, socket),
    do: run(socket, &Content.show_page/2, gettext("Page shown in the menus again."))

  def handle_event("transition", %{"to" => "archived"}, socket),
    do: run(socket, &Content.archive_page/2, gettext("Page archived; it is offline now."))

  def handle_event("restore", %{"id" => version_id}, socket) do
    run(
      socket,
      &Content.restore_page_version(&1, version_id, &2),
      gettext("Version restored into the working copy. Publish it to make it visible.")
    )
  end

  # --- blocks ---

  def handle_event("add_block", %{"type" => type}, socket) do
    {:noreply, edit_block(socket, Blocks.new(type))}
  end

  def handle_event("edit_block", %{"id" => id}, socket) do
    block =
      socket.assigns.page.blocks
      |> Enum.map(&Blocks.to_input/1)
      |> Enum.find(&(&1["id"] == id))

    {:noreply, edit_block(socket, block)}
  end

  def handle_event("cancel_block", _params, socket) do
    {:noreply, assign(socket, block_form: nil, editing_block: nil)}
  end

  def handle_event("save_block", %{"block" => params}, socket) do
    block =
      Map.merge(socket.assigns.editing_block, block_params(socket.assigns.editing_block, params))

    case update_blocks(socket, &Blocks.put(&1, block)) do
      {:ok, socket} ->
        {:noreply, assign(socket, block_form: nil, editing_block: nil)}

      {:error, socket} ->
        {:noreply, socket}
    end
  end

  def handle_event("delete_block", %{"id" => id}, socket) do
    {_result, socket} = update_blocks(socket, &Blocks.delete(&1, id))
    {:noreply, socket}
  end

  def handle_event("reorder_blocks", %{"id" => id, "index" => index}, socket) do
    {_result, socket} = update_blocks(socket, &Blocks.move(&1, id, index))
    {:noreply, socket}
  end

  defp edit_block(socket, block) do
    form = to_form(Map.drop(block, ["id", "type"]), as: :block, id: "block-#{block["id"]}")
    assign(socket, block_form: form, editing_block: block)
  end

  # only the fields of the block type; drops LiveView's _unused_ keys
  defp block_params(%{"type" => type}, params) do
    {_type, module} = Enum.find(Blocks.types(), fn {t, _module} -> t == type end)
    fields = module |> Info.attributes() |> Enum.map(&to_string(&1.name))
    params |> Map.take(fields -- ["id", "type"]) |> Map.new(fn {k, v} -> {k, clean(v)} end)
  end

  defp clean(value) when is_map(value),
    do: value |> Enum.reject(fn {k, _v} -> String.starts_with?(k, "_unused_") end) |> Map.new()

  defp clean(value), do: value

  defp settings_params(params) do
    Map.take(params, ~w(title seo_description slug menu key))
    |> Map.new(fn {k, v} -> {k, clean(v)} end)
  end

  defp update_blocks(socket, fun) do
    case Content.update_page_blocks(socket.assigns.page, fun, socket.assigns.current_user) do
      {:ok, page} ->
        {:ok, assign_page(socket, page)}

      {:error, _error} ->
        {:error, put_flash(socket, :error, gettext("The block could not be saved."))}
    end
  end

  defp run(socket, fun, message) do
    case fun.(socket.assigns.page, actor: socket.assigns.current_user) do
      {:ok, page} ->
        {:noreply, socket |> put_flash(:info, message) |> assign_page(page)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("This change is not possible."))}
    end
  end

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="pages">
      <.link navigate={~p"/admin/pages"} class="link link-hover text-sm w-fit" id="back-to-pages">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("Pages")}
      </.link>

      <div class="flex flex-wrap items-center gap-2">
        <h1 class="text-3xl font-bold" id="page-heading">{Translated.t(@page.title, @locale)}</h1>
        <.page_state_badge state={@page.state} id="page-state" />
        <span :if={@page.changes_pending} class="badge badge-info badge-outline" id="changes-pending">
          {gettext("Unpublished changes")}
        </span>
      </div>
      <p class="text-sm text-base-content/70">/pages/{@page.path}</p>

      <div class="flex flex-wrap gap-2" id="page-actions">
        <a
          href={~p"/pages/#{String.split(@page.path, "/")}?preview=1"}
          target="_blank"
          class="btn btn-sm"
          id="preview-link"
        >
          <.icon name="hero-eye" class="size-4" /> {gettext("Preview")}
        </a>
        <button
          :if={@page.state in [:draft, :archived] or @page.changes_pending}
          type="button"
          phx-click="publish"
          class="btn btn-primary btn-sm"
          id="publish"
        >
          <.icon name="hero-globe-alt" class="size-4" /> {gettext("Publish")}
        </button>
        <button
          :if={@page.published && @page.changes_pending}
          type="button"
          phx-click="discard"
          data-confirm={gettext("Discard all changes since the last publication?")}
          class="btn btn-sm btn-ghost"
          id="discard"
        >
          {gettext("Discard changes")}
        </button>
        <button
          :if={@page.state == :published}
          type="button"
          phx-click="transition"
          phx-value-to="hidden"
          class="btn btn-sm btn-ghost"
          id="hide"
        >
          {gettext("Hide from menus")}
        </button>
        <button
          :if={@page.state == :hidden}
          type="button"
          phx-click="transition"
          phx-value-to="published"
          class="btn btn-sm btn-ghost"
          id="show"
        >
          {gettext("Show in menus")}
        </button>
        <button
          :if={@page.state in [:published, :hidden]}
          type="button"
          phx-click="transition"
          phx-value-to="archived"
          data-confirm={gettext("Take this page offline?")}
          class="btn btn-sm btn-ghost text-error"
          id="archive"
        >
          {gettext("Archive")}
        </button>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <section class="space-y-3">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h2 class="text-xl font-semibold">{gettext("Content")}</h2>
            <div class="flex gap-1">
              <button
                :for={{type, _module} <- Blocks.types()}
                type="button"
                phx-click="add_block"
                phx-value-type={type}
                class="btn btn-sm"
                id={"add-block-#{type}"}
              >
                <.icon name="hero-plus" class="size-4" /> {block_type_label(type)}
              </button>
            </div>
          </div>

          <div id="blocks" phx-hook="Sortable" data-event="reorder_blocks">
            <p
              :if={@page.blocks == []}
              class="rounded-box bg-base-100 p-6 text-base-content/70 shadow-sm"
              id="no-blocks"
            >
              {gettext("No content yet. Add a block.")}
            </p>
            <ul data-sortable-list class="space-y-3">
              <li
                :for={block <- @page.blocks}
                data-id={block.value.id}
                id={"edit-block-#{block.value.id}"}
                class="card bg-base-100 shadow-sm"
              >
                <div class="flex items-center gap-1 border-b border-base-200 px-3 py-1 text-sm">
                  <span
                    data-sortable-handle
                    class="cursor-grab text-base-content/40"
                    title={gettext("Drag")}
                  >
                    <.icon name="hero-bars-2" class="size-5" />
                  </span>
                  <span class="text-base-content/60">{block_type_label(to_string(block.type))}</span>
                  <div class="ml-auto flex gap-1">
                    <button
                      type="button"
                      phx-click="edit_block"
                      phx-value-id={block.value.id}
                      class="btn btn-ghost btn-xs"
                      id={"edit-#{block.value.id}"}
                    >
                      <.icon name="hero-pencil-square" class="size-4" /> {gettext("Edit")}
                    </button>
                    <button
                      type="button"
                      phx-click="delete_block"
                      phx-value-id={block.value.id}
                      data-confirm={gettext("Delete this block?")}
                      class="btn btn-ghost btn-xs text-error"
                      title={gettext("Delete")}
                      id={"delete-#{block.value.id}"}
                    >
                      <.icon name="hero-trash" class="size-4" />
                    </button>
                  </div>
                </div>
                <div class="p-4">
                  <.block block={block} locale={@locale} />
                </div>
              </li>
            </ul>
          </div>
        </section>

        <aside class="space-y-6">
          <section class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h2 class="card-title">{gettext("Settings")}</h2>
              <.form for={@settings_form} id="settings-form" phx-change="validate" phx-submit="save">
                <.translated_input field={@settings_form[:title]} label={gettext("Title")} />
                <.input field={@settings_form[:slug]} label={gettext("URL name (slug)")} />
                <.input
                  field={@settings_form[:menu]}
                  type="select"
                  label={gettext("Menu")}
                  options={menu_options()}
                />
                <.translated_input
                  field={@settings_form[:seo_description]}
                  label={gettext("Description for search engines")}
                  type="textarea"
                  rows="2"
                />
                <.input
                  :if={:administrator in @current_user.roles}
                  field={@settings_form[:key]}
                  label={gettext("Key for links from the code (e.g. imprint)")}
                />
                <button type="submit" class="btn btn-primary btn-sm mt-2" id="save-settings">
                  {gettext("Save")}
                </button>
              </.form>
            </div>
          </section>

          <section class="card bg-base-100 shadow-sm" id="history">
            <div class="card-body gap-2">
              <h2 class="card-title">{gettext("History")}</h2>
              <p :if={@versions == []} class="text-sm text-base-content/70">
                {gettext("Not published yet.")}
              </p>
              <ul class="divide-y divide-base-200 text-sm">
                <li
                  :for={version <- @versions}
                  class="flex items-center gap-2 py-2"
                  id={"version-#{version.id}"}
                >
                  <div class="flex-1">
                    <p class="font-medium">{Format.datetime(version.version_inserted_at)}</p>
                    <p class="text-base-content/60">
                      {(version.user && (version.user.name || to_string(version.user.email))) || "–"}
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="restore"
                    phx-value-id={version.id}
                    data-confirm={gettext("Copy this version into the working copy?")}
                    class="btn btn-ghost btn-xs"
                    id={"restore-#{version.id}"}
                  >
                    <.icon name="hero-arrow-uturn-left" class="size-4" /> {gettext("Restore")}
                  </button>
                </li>
              </ul>
            </div>
          </section>
        </aside>
      </div>

      <div :if={@block_form} class="modal modal-open" id="block-modal">
        <div class="modal-box max-w-4xl">
          <h2 class="text-xl font-bold">{block_type_label(@editing_block["type"])}</h2>
          <.form for={@block_form} id="block-form" phx-submit="save_block" class="mt-4">
            <.block_fields type={@editing_block["type"]} form={@block_form} />
            <div class="modal-action">
              <button type="button" phx-click="cancel_block" class="btn btn-ghost">{gettext("Cancel")}</button>
              <button type="submit" class="btn btn-primary" id="save-block">{gettext("Apply")}</button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :type, :string, required: true
  attr :form, :any, required: true

  defp block_fields(%{type: "text"} = assigns) do
    ~H"""
    <.translated_input field={@form[:text]} label={gettext("Text")} type="markdown" />
    """
  end

  defp block_type_label("text"), do: gettext("Text")
end
