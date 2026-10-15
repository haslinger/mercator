defmodule MercatorWeb.Admin.MediaLive do
  @moduledoc """
  The media library (`/admin/media`, CMS step 4, #85): upload images and
  PDFs with tags, find them by text, tag and kind, edit title, alt text and
  tags, delete unused files.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.TranslatedComponents

  alias Mercator.Content
  alias Mercator.Content.Asset
  alias Mercator.Translated

  on_mount {MercatorWeb.LiveUserAuth, {:require_any_role, [:contentmanager, :administrator]}}

  @filters ~w(q tag kind)
  @max_size 20_000_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Media"))
     |> assign(:upload_tags, "")
     |> assign(:editing, nil)
     |> allow_upload(:files,
       accept: ~w(.jpg .jpeg .png .webp .pdf),
       max_entries: 20,
       max_file_size: @max_size
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = params |> Map.take(@filters) |> Enum.reject(fn {_k, v} -> v == "" end) |> Map.new()
    {:noreply, socket |> assign(:filters, filters) |> load()}
  end

  defp load(socket) do
    filters = socket.assigns.filters

    assets =
      Content.search_assets!(
        %{
          query: filters["q"],
          tag: filters["tag"],
          kind: Enum.find([:image, :document], &(to_string(&1) == filters["kind"]))
        },
        actor: socket.assigns.current_user
      )

    socket
    |> assign(:assets, assets)
    |> assign(:tags, Content.asset_tags())
  end

  # --- events ---

  @impl true
  def handle_event("filter", params, socket) do
    query =
      params |> Map.take(@filters) |> Enum.reject(fn {_k, v} -> v in [nil, ""] end) |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/admin/media?#{query}")}
  end

  def handle_event("validate_upload", params, socket) do
    {:noreply, assign(socket, :upload_tags, params["tags"] || "")}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event("upload", params, socket) do
    tags = String.split(params["tags"] || "", ",")

    if Enum.all?(tags, &(String.trim(&1) == "")) do
      {:noreply, put_flash(socket, :error, gettext("Please enter at least one tag."))}
    else
      results =
        consume_uploaded_entries(socket, :files, fn %{path: path}, entry ->
          attrs = %{
            source_path: path,
            original_filename: entry.client_name,
            title: %{"de" => Path.rootname(entry.client_name)},
            tags: tags
          }

          {:ok, Content.upload_asset(attrs, actor: socket.assigns.current_user)}
        end)

      failed = Enum.count(results, &match?({:error, _}, &1))
      uploaded = length(results) - failed

      socket =
        if failed > 0,
          do:
            put_flash(
              socket,
              :error,
              ngettext(
                "1 file is neither an image nor a PDF.",
                "%{count} files are neither images nor PDFs.",
                failed
              )
            ),
          else:
            put_flash(
              socket,
              :info,
              ngettext("1 file uploaded.", "%{count} files uploaded.", uploaded)
            )

      {:noreply, socket |> assign(:upload_tags, "") |> load()}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    asset = Enum.find(socket.assigns.assets, &(&1.id == id))
    form = asset |> Content.form_to_update_asset(actor: socket.assigns.current_user) |> to_form()
    {:noreply, assign(socket, editing: asset, form: form)}
  end

  def handle_event("close", _params, socket), do: {:noreply, assign(socket, :editing, nil)}

  def handle_event("save", %{"form" => params}, socket) do
    params = Map.update(params, "tags", [], &String.split(&1, ","))

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _asset} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Saved."))
         |> assign(:editing, nil)
         |> load()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    asset = Enum.find(socket.assigns.assets, &(&1.id == id))

    case Content.destroy_asset(asset, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket |> put_flash(:info, gettext("File deleted.")) |> assign(:editing, nil) |> load()}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, gettext("The file is used on a page and cannot be deleted."))}
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
      active="media"
    >
      <h1 class="text-3xl font-bold">{gettext("Media")}</h1>

      <form
        id="upload-form"
        phx-change="validate_upload"
        phx-submit="upload"
        class="card bg-base-100 shadow-sm"
      >
        <div class="card-body gap-3">
          <label
            for={@uploads.files.ref}
            phx-drop-target={@uploads.files.ref}
            class="flex cursor-pointer flex-col items-center gap-2 rounded-box border-2 border-dashed border-base-300 p-6 text-center hover:border-primary"
            id="drop-zone"
          >
            <.icon name="hero-arrow-up-tray" class="size-8 text-base-content/40" />
            <span class="font-medium">{gettext("Drop images or PDFs here or click to choose")}</span>
            <span class="text-sm text-base-content/60">
              {gettext("JPEG, PNG, WebP or PDF, up to 20 MB each. Images are converted to WebP.")}
            </span>
          </label>
          <.live_file_input upload={@uploads.files} class="hidden" />

          <div :if={@uploads.files.entries != []} class="space-y-2" id="upload-entries">
            <div
              :for={entry <- @uploads.files.entries}
              class="flex items-center gap-3"
              id={"entry-#{entry.ref}"}
            >
              <span class="flex-1 truncate text-sm">{entry.client_name}</span>
              <progress class="progress progress-primary w-32" value={entry.progress} max="100"></progress>
              <span :for={error <- upload_errors(@uploads.files, entry)} class="text-sm text-error">
                {error_text(error)}
              </span>
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                class="btn btn-ghost btn-xs"
                aria-label={gettext("Cancel")}
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
            <div class="flex flex-wrap items-end gap-2">
              <label class="fieldset grow">
                <span class="label">{gettext("Tags (comma-separated, at least one)")}</span>
                <input
                  type="text"
                  name="tags"
                  value={@upload_tags}
                  list="known-tags"
                  class="input w-full"
                  id="upload-tags"
                />
              </label>
              <button type="submit" class="btn btn-primary" id="upload-files">
                {gettext("Upload")}
              </button>
            </div>
          </div>
        </div>
      </form>
      <datalist id="known-tags">
        <option :for={tag <- @tags} value={tag} />
      </datalist>

      <form id="media-filters" phx-change="filter" phx-submit="filter" class="flex flex-wrap gap-2">
        <label class="input input-sm w-64">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
          <input
            type="search"
            name="q"
            value={@filters["q"]}
            placeholder={gettext("Title, file name or tag")}
            phx-debounce="300"
            id="media-search"
          />
        </label>
        <select name="tag" class="select select-sm w-44" id="filter-tag">
          <option value="">{gettext("All tags")}</option>
          <option :for={tag <- @tags} value={tag} selected={@filters["tag"] == tag}>{tag}</option>
        </select>
        <select name="kind" class="select select-sm w-36" id="filter-kind">
          <option value="">{gettext("All files")}</option>
          <option value="image" selected={@filters["kind"] == "image"}>{gettext("Images")}</option>
          <option value="document" selected={@filters["kind"] == "document"}>
            {gettext("PDFs")}
          </option>
        </select>
      </form>

      <p :if={@assets == []} class="text-base-content/70" id="no-assets">
        {gettext("No files found.")}
      </p>
      <ul class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5" id="assets">
        <li :for={asset <- @assets} id={"asset-#{asset.id}"}>
          <button
            type="button"
            phx-click="edit"
            phx-value-id={asset.id}
            class="card w-full bg-base-100 text-left shadow-sm transition hover:shadow-md"
          >
            <figure class="aspect-[4/3] bg-base-200">
              <img
                :if={asset.kind == :image}
                src={Asset.url(asset, :thumb)}
                alt={Translated.t(asset.alt, @locale) || ""}
                class="h-full w-full object-cover"
                loading="lazy"
              />
              <.icon
                :if={asset.kind == :document}
                name="hero-document-text"
                class="size-12 text-base-content/40"
              />
            </figure>
            <div class="card-body gap-1 p-3">
              <p class="truncate text-sm font-medium">
                {Translated.t(asset.title, @locale) || asset.original_filename}
              </p>
              <div class="flex flex-wrap gap-1">
                <span :for={tag <- asset.tags} class="badge badge-ghost badge-xs">{tag}</span>
              </div>
            </div>
          </button>
        </li>
      </ul>

      <div :if={@editing} class="modal modal-open" id="asset-modal">
        <div class="modal-box max-w-2xl">
          <div class="flex gap-4">
            <img
              :if={@editing.kind == :image}
              src={Asset.url(@editing, :thumb)}
              alt=""
              class="size-28 rounded object-cover"
            />
            <div class="min-w-0 text-sm">
              <p class="truncate font-medium">{@editing.original_filename}</p>
              <p :if={@editing.width} class="text-base-content/60">
                {@editing.width} × {@editing.height} px
              </p>
              <a href={Asset.url(@editing)} target="_blank" class="link text-sm">{gettext("Open file")}</a>
              <label class="mt-2 block">
                <span class="text-xs text-base-content/60">{gettext("For Markdown texts")}</span>
                <input
                  type="text"
                  readonly
                  value={markdown_snippet(@editing, @locale)}
                  class="input input-sm w-full font-mono"
                  id="markdown-snippet"
                />
              </label>
            </div>
          </div>
          <.form for={@form} id="asset-form" phx-submit="save" class="mt-4">
            <.translated_input field={@form[:title]} label={gettext("Title")} />
            <.translated_input
              :if={@editing.kind == :image}
              field={@form[:alt]}
              label={gettext("Alternative text")}
            />
            <.input
              name={@form[:tags].name}
              value={Enum.join(@form[:tags].value || [], ", ")}
              label={gettext("Tags (comma-separated, at least one)")}
              list="known-tags"
              id="asset-tags"
              errors={Enum.map(@form[:tags].errors, &translate_error/1)}
            />
            <div class="modal-action">
              <button
                type="button"
                phx-click="delete"
                phx-value-id={@editing.id}
                data-confirm={gettext("Delete this file?")}
                class="btn btn-ghost text-error mr-auto"
                id="delete-asset"
              >
                {gettext("Delete")}
              </button>
              <button type="button" phx-click="close" class="btn btn-ghost">{gettext("Cancel")}</button>
              <button type="submit" class="btn btn-primary" id="save-asset">{gettext("Save")}</button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp markdown_snippet(%{kind: :image} = asset, locale),
    do: "![#{Translated.t(asset.alt, locale) || ""}](#{Asset.url(asset)})"

  defp markdown_snippet(asset, locale),
    do: "[#{Translated.t(asset.title, locale) || asset.original_filename}](#{Asset.url(asset)})"

  defp error_text(:too_large), do: gettext("The file is too large.")
  defp error_text(:not_accepted), do: gettext("Only images (JPEG, PNG, WebP) or PDFs.")
  defp error_text(:too_many_files), do: gettext("Too many files at once.")
  defp error_text(_error), do: gettext("Upload failed.")
end
