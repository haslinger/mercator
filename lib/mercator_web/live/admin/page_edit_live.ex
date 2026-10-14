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
  alias Mercator.{Catalog, Content}
  alias Mercator.Content.{Asset, Blocks}
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
         |> assign(:categories, categories())
         |> assign_page(page)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Page not found."))
         |> push_navigate(to: ~p"/admin/pages")}
    end
  end

  defp categories do
    Catalog.list_categories!(query: [sort: [path: :asc]])
    |> Enum.filter(&(&1.state == :active))
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
    |> assign(:block_data, MercatorWeb.BlockData.load(page.blocks))
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

  def handle_event("block_change", params, socket) do
    block =
      Map.merge(
        socket.assigns.editing_block,
        block_params(socket.assigns.editing_block, params["block"] || %{})
      )

    form = to_form(Map.drop(block, ["id", "type"]), as: :block, id: "block-#{block["id"]}")

    {:noreply,
     socket
     |> assign(editing_block: block, block_form: form)
     |> assign_picker(params["picker_q"] || "")}
  end

  def handle_event("save_block", params, socket) do
    params = params["block"] || %{}

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

    socket
    |> assign(block_form: form, editing_block: block)
    |> assign_picker("")
  end

  # media library files to choose from in the block form, plus the chosen ones
  defp assign_picker(socket, query) do
    block = socket.assigns.editing_block
    kind = if block["type"] == "download", do: :document, else: :image

    found =
      Content.search_assets!(%{query: query, kind: kind}, actor: socket.assigns.current_user)

    chosen =
      Content.assets_by_ids([block["image_id"], block["document_id"] | block["image_ids"] || []])

    missing = Enum.reject(Map.values(chosen), &(&1 in found))

    assign(socket, picker_query: query, picker_assets: missing ++ Enum.take(found, 48))
  end

  # only the fields of the block type; drops LiveView's _unused_ keys
  defp block_params(%{"type" => type}, params) do
    {_type, module} = Enum.find(Blocks.types(), fn {t, _module} -> t == type end)
    fields = module |> Info.attributes() |> Enum.map(&to_string(&1.name))
    params |> Map.take(fields -- ["id", "type"]) |> Map.new(fn {k, v} -> {k, clean(v)} end)
  end

  defp clean(value) when is_map(value),
    do: value |> Enum.reject(fn {k, _v} -> String.starts_with?(k, "_unused_") end) |> Map.new()

  defp clean(value) when is_list(value), do: Enum.reject(value, &(&1 == ""))
  defp clean(""), do: nil
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
                  <.block block={block} locale={@locale} data={@block_data} />
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
          <.form
            for={@block_form}
            id="block-form"
            phx-change="block_change"
            phx-submit="save_block"
            class="mt-4 space-y-2"
          >
            <.block_fields
              type={@editing_block["type"]}
              form={@block_form}
              block={@editing_block}
              picker_assets={@picker_assets}
              picker_query={@picker_query}
              categories={@categories}
              locale={@locale}
            />
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
  attr :block, :map, required: true
  attr :picker_assets, :list, required: true
  attr :picker_query, :string, required: true
  attr :categories, :list, required: true
  attr :locale, :string, required: true

  defp block_fields(%{type: "text"} = assigns) do
    ~H"""
    <.translated_input field={@form[:text]} label={gettext("Text")} type="markdown" />
    """
  end

  defp block_fields(%{type: "hero"} = assigns) do
    ~H"""
    <.asset_picker name="block[image_id]" selected={[@block["image_id"]]} {picker(assigns)} />
    <.translated_input field={@form[:headline]} label={gettext("Headline")} />
    <.translated_input field={@form[:text]} label={gettext("Text")} type="markdown" />
    <.translated_input field={@form[:button_label]} label={gettext("Button label")} />
    <.input
      field={@form[:button_link]}
      label={gettext("Button link, e.g. /categories/bauholz or /pages/kontakt")}
    />
    """
  end

  defp block_fields(%{type: "text_image"} = assigns) do
    ~H"""
    <.translated_input field={@form[:text]} label={gettext("Text")} type="markdown" />
    <.asset_picker name="block[image_id]" selected={[@block["image_id"]]} {picker(assigns)} />
    <.input
      field={@form[:image_side]}
      type="select"
      label={gettext("Image position")}
      options={[{gettext("right of the text"), "right"}, {gettext("left of the text"), "left"}]}
    />
    """
  end

  defp block_fields(%{type: "image"} = assigns) do
    ~H"""
    <.asset_picker name="block[image_id]" selected={[@block["image_id"]]} {picker(assigns)} />
    <.translated_input field={@form[:caption]} label={gettext("Caption")} />
    """
  end

  defp block_fields(%{type: "gallery"} = assigns) do
    ~H"""
    <.asset_picker
      name="block[image_ids][]"
      selected={@block["image_ids"] || []}
      multiple
      {picker(assigns)}
    />
    """
  end

  defp block_fields(%{type: "download"} = assigns) do
    ~H"""
    <.asset_picker name="block[document_id]" selected={[@block["document_id"]]} {picker(assigns)} />
    <.translated_input
      field={@form[:label]}
      label={gettext("Link text (default: the file's title)")}
    />
    """
  end

  defp block_fields(%{type: "products"} = assigns) do
    ~H"""
    <.translated_input field={@form[:heading]} label={gettext("Heading")} />
    <.input
      field={@form[:source]}
      type="select"
      label={gettext("Products")}
      options={[
        {gettext("Bestsellers"), "bestsellers"},
        {gettext("New arrivals"), "new_arrivals"},
        {gettext("From a category"), "category"},
        {gettext("Chosen article numbers"), "numbers"}
      ]}
    />
    <.input
      :if={to_string(@block["source"]) == "category"}
      field={@form[:category_id]}
      type="select"
      label={gettext("Category (with subcategories)")}
      options={category_options(@categories, @locale)}
      prompt={gettext("Choose a category")}
    />
    <.input
      :if={to_string(@block["source"]) == "numbers"}
      field={@form[:numbers]}
      label={gettext("Article numbers of the products, separated by commas")}
    />
    <.input
      field={@form[:limit]}
      type="number"
      min="1"
      max="24"
      label={gettext("Maximum number")}
    />
    """
  end

  defp block_fields(%{type: "categories"} = assigns) do
    assigns =
      assign(assigns, :chosen, Enum.map(assigns.block["category_ids"] || [], &to_string/1))

    ~H"""
    <.translated_input field={@form[:heading]} label={gettext("Heading")} />
    <fieldset class="fieldset">
      <legend class="fieldset-legend">
        {gettext("Categories (none chosen: the main categories)")}
      </legend>
      <input type="hidden" name="block[category_ids][]" value="" />
      <div class="max-h-64 overflow-y-auto">
        <label
          :for={category <- @categories}
          class="label flex text-base-content"
          style={"padding-left: #{(length(category.path) - 1) * 1.25}rem"}
        >
          <input
            type="checkbox"
            name="block[category_ids][]"
            value={category.id}
            checked={category.id in @chosen}
            class="checkbox checkbox-sm"
            id={"block-category-#{category.id}"}
          />
          {Translated.t(category.name, @locale)}
        </label>
      </div>
    </fieldset>
    """
  end

  defp block_fields(%{type: "call_to_action"} = assigns) do
    ~H"""
    <.translated_input field={@form[:headline]} label={gettext("Headline")} />
    <.translated_input field={@form[:text]} label={gettext("Text")} type="markdown" />
    <.translated_input field={@form[:button_label]} label={gettext("Button label")} />
    <.input
      field={@form[:button_link]}
      label={gettext("Button link, e.g. /categories/bauholz or /pages/kontakt")}
    />
    """
  end

  defp category_options(categories, locale) do
    Enum.map(categories, fn category ->
      {String.duplicate("– ", length(category.path) - 1) <> Translated.t(category.name, locale),
       category.id}
    end)
  end

  defp picker(assigns),
    do: %{assets: assigns.picker_assets, query: assigns.picker_query, locale: assigns.locale}

  attr :name, :string, required: true
  attr :selected, :list, required: true
  attr :multiple, :boolean, default: false
  attr :assets, :list, required: true
  attr :query, :string, required: true
  attr :locale, :string, required: true

  # Files of the media library as radio buttons (or checkboxes) with
  # thumbnails, searchable; uploading happens in the media library.
  defp asset_picker(assigns) do
    assigns = assign(assigns, :selected, Enum.map(assigns.selected, &to_string/1))

    ~H"""
    <fieldset class="fieldset" id="asset-picker">
      <legend class="fieldset-legend">
        {if @multiple, do: gettext("Images"), else: gettext("File from the media library")}
      </legend>
      <div class="flex flex-wrap items-center gap-2">
        <input
          type="search"
          name="picker_q"
          value={@query}
          placeholder={gettext("Search the media library")}
          phx-debounce="300"
          class="input input-sm w-64"
          id="picker-search"
        />
        <.link navigate={~p"/admin/media"} target="_blank" class="link text-sm">
          {gettext("Upload in the media library")}
        </.link>
      </div>
      <input :if={@multiple} type="hidden" name={@name} value="" />
      <p :if={@assets == []} class="text-sm text-base-content/60">{gettext("No files found.")}</p>
      <div class="grid max-h-64 grid-cols-3 gap-2 overflow-y-auto sm:grid-cols-5 lg:grid-cols-6">
        <label
          :for={asset <- @assets}
          class={[
            "relative cursor-pointer overflow-hidden rounded-box border-2",
            if(asset.id in @selected, do: "border-primary", else: "border-transparent")
          ]}
          title={Translated.t(asset.title, @locale) || asset.original_filename}
          id={"pick-#{asset.id}"}
        >
          <input
            type={if @multiple, do: "checkbox", else: "radio"}
            name={@name}
            value={asset.id}
            checked={asset.id in @selected}
            class="sr-only"
          />
          <img
            :if={asset.kind == :image}
            src={Asset.url(asset, :thumb)}
            alt=""
            class="aspect-square w-full object-cover"
          />
          <span
            :if={asset.kind == :document}
            class="flex aspect-square flex-col items-center justify-center gap-1 bg-base-200 p-1 text-center text-xs"
          >
            <.icon name="hero-document-text" class="size-6" />
            <span class="line-clamp-2">
              {Translated.t(asset.title, @locale) || asset.original_filename}
            </span>
          </span>
          <.icon
            :if={asset.id in @selected}
            name="hero-check-circle-solid"
            class="absolute right-1 top-1 size-5 text-primary"
          />
        </label>
      </div>
    </fieldset>
    """
  end

  defp block_type_label("text"), do: gettext("Text")
  defp block_type_label("hero"), do: gettext("Hero")
  defp block_type_label("text_image"), do: gettext("Text with image")
  defp block_type_label("image"), do: gettext("Image")
  defp block_type_label("gallery"), do: gettext("Gallery")
  defp block_type_label("download"), do: gettext("Download")
  defp block_type_label("products"), do: gettext("Products")
  defp block_type_label("categories"), do: gettext("Categories")
  defp block_type_label("call_to_action"), do: gettext("Call to action")
end
