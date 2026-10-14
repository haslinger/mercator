defmodule MercatorWeb.ContentComponents do
  @moduledoc """
  Rendering of CMS blocks (docs/cms-design.md, section 3). Each block type
  of `Mercator.Content.Block` has one clause of `block/1`. Blocks that show
  media library files get them from the `assets` map (id => asset, see
  `Mercator.Content.assets_for_blocks/1`); a missing file is left out.
  """
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext

  import MercatorWeb.MarkdownComponents, only: [markdown: 1]
  import MercatorWeb.CoreComponents, only: [icon: 1]

  alias Mercator.Content.{Asset, Blocks}
  alias Mercator.Translated

  attr :block, Ash.Union, required: true
  attr :locale, :string, required: true
  attr :assets, :map, default: %{}

  def block(%{block: %Ash.Union{value: value}} = assigns) do
    assigns = assign(assigns, :b, value)
    render_block(assigns)
  end

  defp render_block(%{b: %Blocks.Text{}} = assigns) do
    ~H"""
    <section class="block-text" id={"block-#{@b.id}"}>
      <.markdown text={t(@b.text, @locale)} class="max-w-3xl" />
    </section>
    """
  end

  defp render_block(%{b: %Blocks.Hero{}} = assigns) do
    assigns = assign(assigns, :image, assigns.assets[assigns.b.image_id])

    ~H"""
    <section
      class="hero min-h-[22rem] overflow-hidden rounded-box bg-base-300 bg-cover bg-center"
      style={@image && "background-image: url('#{Asset.url(@image, :wide)}')"}
      id={"block-#{@b.id}"}
    >
      <div :if={@image} class="hero-overlay bg-black/40"></div>
      <div class={["hero-content max-w-3xl text-center", @image && "text-white"]}>
        <div class="space-y-4">
          <h2 :if={t(@b.headline, @locale)} class="text-4xl font-bold">{t(@b.headline, @locale)}</h2>
          <.markdown text={t(@b.text, @locale)} class="text-lg" />
          <a
            :if={t(@b.button_label, @locale) && @b.button_link}
            href={@b.button_link}
            class="btn btn-primary"
          >
            {t(@b.button_label, @locale)}
          </a>
        </div>
      </div>
    </section>
    """
  end

  defp render_block(%{b: %Blocks.TextImage{}} = assigns) do
    assigns = assign(assigns, :image, assigns.assets[assigns.b.image_id])

    ~H"""
    <section class="grid items-center gap-6 md:grid-cols-2" id={"block-#{@b.id}"}>
      <.markdown text={t(@b.text, @locale)} class={@b.image_side == :left && "md:order-2"} />
      <.asset_image :if={@image} asset={@image} locale={@locale} class="w-full rounded-box" />
    </section>
    """
  end

  defp render_block(%{b: %Blocks.Image{}} = assigns) do
    assigns = assign(assigns, :image, assigns.assets[assigns.b.image_id])

    ~H"""
    <figure :if={@image} class="space-y-2" id={"block-#{@b.id}"}>
      <.asset_image asset={@image} locale={@locale} class="w-full rounded-box" />
      <figcaption :if={t(@b.caption, @locale)} class="text-sm text-base-content/70">
        {t(@b.caption, @locale)}
      </figcaption>
    </figure>
    """
  end

  defp render_block(%{b: %Blocks.Gallery{}} = assigns) do
    assigns =
      assign(
        assigns,
        :images,
        assigns.b.image_ids |> Enum.map(&assigns.assets[&1]) |> Enum.reject(&is_nil/1)
      )

    ~H"""
    <section class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4" id={"block-#{@b.id}"}>
      <a :for={image <- @images} href={Asset.url(image, :wide)} target="_blank" class="block">
        <img
          src={Asset.url(image, :thumb)}
          alt={t(image.alt, @locale) || ""}
          class="aspect-square w-full rounded-box object-cover transition hover:opacity-90"
          loading="lazy"
        />
      </a>
    </section>
    """
  end

  defp render_block(%{b: %Blocks.Download{}} = assigns) do
    assigns = assign(assigns, :document, assigns.assets[assigns.b.document_id])

    ~H"""
    <a
      :if={@document}
      href={Asset.url(@document)}
      target="_blank"
      class="flex max-w-xl items-center gap-4 rounded-box bg-base-100 p-4 shadow-sm transition hover:shadow-md"
      id={"block-#{@b.id}"}
    >
      <.icon name="hero-document-arrow-down" class="size-10 shrink-0 text-primary" />
      <span class="min-w-0">
        <span class="block font-semibold">
          {t(@b.label, @locale) || t(@document.title, @locale) || @document.original_filename}
        </span>
        <span class="text-sm text-base-content/60">PDF · {file_size(@document.byte_size)}</span>
      </span>
    </a>
    """
  end

  attr :asset, :any, required: true
  attr :locale, :string, required: true
  attr :class, :any, default: nil

  defp asset_image(assigns) do
    ~H"""
    <img
      src={Asset.url(@asset, :large)}
      srcset={"#{Asset.url(@asset, :large)} 1024w, #{Asset.url(@asset, :wide)} 1920w"}
      sizes="(min-width: 1024px) 50vw, 100vw"
      alt={t(@asset.alt, @locale) || ""}
      class={@class}
      loading="lazy"
    />
    """
  end

  defp t(value, locale), do: Translated.t(value, locale)

  defp file_size(nil), do: ""
  defp file_size(bytes) when bytes < 1_000_000, do: "#{max(div(bytes, 1000), 1)} kB"
  defp file_size(bytes), do: "#{Float.round(bytes / 1_000_000, 1)} MB"
end
