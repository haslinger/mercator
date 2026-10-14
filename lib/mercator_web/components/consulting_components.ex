defmodule MercatorWeb.ConsultingComponents do
  @moduledoc """
  Parts of guided selling shown in the customer's chat and on the sales
  desk: attachments of messages (guided selling step 3, #96).
  """
  use MercatorWeb, :html

  import MercatorWeb.CatalogComponents, only: [catalog_image: 1, first_image: 1]

  alias Mercator.Catalog
  alias Mercator.Content.Asset
  alias Mercator.Translated
  alias MercatorWeb.Format

  attr :message, :map, required: true
  attr :locale, :string, required: true

  attr :desk, :boolean,
    default: false,
    doc: "on the sales desk links open in a new tab, not in the shop the consultant is in"

  @doc "The attachment of a message as a card: product, link or file."
  def attachment(%{message: %{product: %{} = product}} = assigns) do
    assigns =
      assign(assigns,
        product: product,
        price:
          case Catalog.from_price(product) do
            {:ok, info} -> info
            _ -> nil
          end
      )

    ~H"""
    <.shop_link
      path={~p"/products/#{@product.slug}"}
      desk={@desk}
      class="mt-1 block w-72 max-w-full overflow-hidden rounded-box bg-base-100 text-base-content shadow-sm transition hover:shadow-md"
      id={"attachment-#{@message.id}"}
    >
      <.catalog_image
        image={first_image(@product)}
        label={Translated.t(@product.title, @locale)}
        class="aspect-[4/3] w-full"
      />
      <span class="block space-y-1 p-3">
        <span class="line-clamp-2 font-semibold">{Translated.t(@product.title, @locale)}</span>
        <span class="flex items-center justify-between gap-2 text-sm">
          <span :if={@price} class="text-base-content/70">
            {gettext("from %{amount}", amount: Format.money(@price.unit_gross, @locale))}
          </span>
          <span class="ml-auto font-semibold text-primary">
            {gettext("View")} <.icon name="hero-arrow-right" class="size-4" />
          </span>
        </span>
      </span>
    </.shop_link>
    """
  end

  def attachment(%{message: %{link_url: "/" <> _ = path}} = assigns) do
    assigns = assign(assigns, :path, path)

    ~H"""
    <.shop_link
      path={@path}
      desk={@desk}
      class="mt-1 flex w-72 max-w-full items-center gap-2 rounded-box bg-base-100 p-2 text-sm text-base-content shadow-sm hover:shadow"
      id={"attachment-#{@message.id}"}
    >
      <.icon name="hero-arrow-right-circle" class="size-6 shrink-0 text-primary" />
      <span class="min-w-0 truncate">{@message.link_title || @path}</span>
    </.shop_link>
    """
  end

  def attachment(%{message: %{link_url: url}} = assigns) when is_binary(url) do
    ~H"""
    <a
      href={@message.link_url}
      target="_blank"
      rel="noopener noreferrer"
      class="mt-1 flex w-72 max-w-full items-center gap-2 rounded-box bg-base-100 p-2 text-sm text-base-content shadow-sm hover:shadow"
      id={"attachment-#{@message.id}"}
    >
      <.icon name="hero-arrow-top-right-on-square" class="size-6 shrink-0 text-primary" />
      <span class="min-w-0">
        <span class="block truncate font-semibold">{@message.link_title ||
          URI.parse(@message.link_url).host}</span>
        <span class="block truncate text-xs text-base-content/60">{@message.link_url}</span>
      </span>
    </a>
    """
  end

  def attachment(%{message: %{asset: %Asset{kind: :image} = asset}} = assigns) do
    assigns = assign(assigns, :asset, asset)

    ~H"""
    <a
      href={Asset.url(@asset, :large)}
      target="_blank"
      class="mt-1 block w-72 max-w-full"
      id={"attachment-#{@message.id}"}
    >
      <img
        src={Asset.url(@asset, :thumb)}
        alt={Translated.t(@asset.alt, @locale) || ""}
        class="w-full rounded-box object-cover"
      />
    </a>
    """
  end

  def attachment(%{message: %{asset: %Asset{} = asset}} = assigns) do
    assigns = assign(assigns, :asset, asset)

    ~H"""
    <a
      href={Asset.url(@asset)}
      target="_blank"
      class="mt-1 flex w-72 max-w-full items-center gap-2 rounded-box bg-base-100 p-2 text-sm text-base-content shadow-sm hover:shadow"
      id={"attachment-#{@message.id}"}
    >
      <.icon name="hero-document-text" class="size-6 shrink-0 text-primary" />
      <span class="min-w-0">
        <span class="block truncate font-semibold">
          {Translated.t(@asset.title, @locale) || @asset.original_filename}
        </span>
        <span class="text-xs text-base-content/60">PDF · {file_size(@asset.byte_size)}</span>
      </span>
    </a>
    """
  end

  def attachment(assigns), do: ~H""

  attr :path, :string, required: true
  attr :desk, :boolean, required: true
  attr :class, :any, default: nil
  attr :id, :string, default: nil
  slot :inner_block, required: true

  # a shop page: in the customer's chat live navigation, on the desk a new tab
  defp shop_link(%{desk: true} = assigns) do
    ~H"""
    <a href={@path} target="_blank" class={@class} id={@id}>{render_slot(@inner_block)}</a>
    """
  end

  defp shop_link(assigns) do
    ~H"""
    <.link navigate={@path} class={@class} id={@id}>{render_slot(@inner_block)}</.link>
    """
  end

  defp file_size(nil), do: ""
  defp file_size(bytes) when bytes < 1_000_000, do: "#{max(div(bytes, 1000), 1)} kB"
  defp file_size(bytes), do: "#{Float.round(bytes / 1_000_000, 1)} MB"
end
