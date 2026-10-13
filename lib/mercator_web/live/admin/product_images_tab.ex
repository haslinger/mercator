defmodule MercatorWeb.Admin.ProductImagesTab do
  @moduledoc """
  Product editor tab "images" (back office step 4c): upload several images
  by drag & drop or file selection (LiveView uploads, converted to WebP by
  `Mercator.Catalog.ImageProcessing`), sort them by drag & drop (the first
  is the main image) and delete them.
  """
  use MercatorWeb, :live_component

  alias Mercator.Catalog
  alias Mercator.Catalog.Image
  alias Mercator.Translated

  @max_size 20_000_000

  @impl true
  def mount(socket) do
    {:ok,
     allow_upload(socket, :images,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 20,
       max_file_size: @max_size
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> load()}
  end

  defp load(socket) do
    product =
      Catalog.get_product!(socket.assigns.product_id,
        actor: socket.assigns.current_user,
        load: :images
      )

    assign(socket, :product, product)
  end

  # --- events ---

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  def handle_event("save", _params, socket) do
    %{product: product, current_user: actor} = socket.assigns
    start = next_position(product.images)

    results =
      consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
        attrs = %{
          product_id: product.id,
          source_path: path,
          original_filename: entry.client_name,
          position: start + entry_index(socket, entry),
          alt: product.title
        }

        {:ok, Catalog.upload_image(attrs, actor: actor)}
      end)

    failed = Enum.count(results, &match?({:error, _}, &1))

    if failed > 0,
      do:
        send(
          self(),
          {:flash, :error,
           ngettext(
             "1 file is not a readable image.",
             "%{count} files are not readable images.",
             failed
           )}
        )

    {:noreply, load(socket)}
  end

  def handle_event("reorder", %{"id" => id, "index" => index}, socket) do
    images = socket.assigns.product.images
    moved = Enum.find(images, &(&1.id == id))

    images
    |> Enum.reject(&(&1.id == id))
    |> List.insert_at(index, moved)
    |> Enum.with_index()
    |> Enum.each(fn {image, position} ->
      if image.position != position,
        do:
          Catalog.update_image!(image, %{position: position}, actor: socket.assigns.current_user)
    end)

    {:noreply, load(socket)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    image = Enum.find(socket.assigns.product.images, &(&1.id == id))
    Catalog.destroy_image!(image, actor: socket.assigns.current_user)
    {:noreply, load(socket)}
  end

  defp next_position(images),
    do: images |> Enum.map(& &1.position) |> Enum.max(fn -> -1 end) |> Kernel.+(1)

  defp entry_index(socket, entry) do
    Enum.find_index(socket.assigns.uploads.images.entries, &(&1.ref == entry.ref)) || 0
  end

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <form id="image-upload-form" phx-change="validate" phx-submit="save" phx-target={@myself}>
        <label
          for={@uploads.images.ref}
          phx-drop-target={@uploads.images.ref}
          class="flex cursor-pointer flex-col items-center gap-2 rounded-box border-2 border-dashed border-base-300 bg-base-100 p-8 text-center hover:border-primary"
          id="image-drop-zone"
        >
          <.icon name="hero-photo" class="size-10 text-base-content/40" />
          <span class="font-medium">{gettext("Drop images here or click to choose")}</span>
          <span class="text-sm text-base-content/60">
            {gettext("JPEG, PNG or WebP, up to 20 MB each. Converted to WebP automatically.")}
          </span>
        </label>
        <.live_file_input upload={@uploads.images} class="hidden" />

        <div :if={@uploads.images.entries != []} class="mt-3 space-y-2" id="upload-entries">
          <div
            :for={entry <- @uploads.images.entries}
            class="flex items-center gap-3"
            id={"entry-#{entry.ref}"}
          >
            <.live_img_preview entry={entry} class="size-12 rounded object-cover" />
            <span class="flex-1 truncate text-sm">{entry.client_name}</span>
            <progress class="progress progress-primary w-32" value={entry.progress} max="100"></progress>
            <span :for={error <- upload_errors(@uploads.images, entry)} class="text-sm text-error">
              {error_text(error)}
            </span>
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
              aria-label={gettext("Cancel")}
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>
          <button type="submit" class="btn btn-primary btn-sm" id="upload-images">
            <.icon name="hero-arrow-up-tray" class="size-4" /> {gettext("Upload")}
          </button>
        </div>
      </form>

      <p :if={@product.images != []} class="text-sm text-base-content/70">
        {gettext("Drag images to sort them. The first image is the main image in the shop.")}
      </p>

      <div id="image-gallery" phx-hook="Sortable" phx-target={@myself} data-event="reorder">
        <div data-sortable-list class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          <figure
            :for={{image, index} <- Enum.with_index(@product.images)}
            data-id={image.id}
            id={"image-#{image.id}"}
            class="card bg-base-100 shadow-sm"
          >
            <div data-sortable-handle class="relative cursor-grab">
              <img
                src={Image.url(image, :thumb)}
                alt={Translated.t(image.alt, @locale)}
                class="aspect-square w-full rounded-t-box object-cover"
              />
              <span :if={index == 0} class="badge badge-primary badge-sm absolute top-2 left-2">
                {gettext("Main image")}
              </span>
            </div>
            <figcaption class="flex items-center gap-2 p-2 text-xs text-base-content/60">
              <span class="flex-1 truncate">{image.original_filename}</span>
              <span>{image.width}×{image.height}</span>
              <button
                type="button"
                phx-click="delete"
                phx-value-id={image.id}
                phx-target={@myself}
                data-confirm={gettext("Delete this image?")}
                class="btn btn-ghost btn-xs text-error"
                id={"delete-image-#{image.id}"}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </figcaption>
          </figure>
        </div>
      </div>

      <p :if={@product.images == []} class="text-base-content/60" id="no-images">
        {gettext("No images yet.")}
      </p>
    </div>
    """
  end

  defp error_text(:too_large), do: gettext("The file is too large.")
  defp error_text(:not_accepted), do: gettext("Only JPEG, PNG or WebP images.")
  defp error_text(:too_many_files), do: gettext("Too many files at once.")
  defp error_text(_error), do: gettext("Upload failed.")
end
