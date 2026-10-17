defmodule MercatorWeb.ContentComponents do
  @moduledoc """
  Rendering of CMS blocks (docs/cms-design.md, section 3). Each block type
  of `Mercator.Content.Block` has one clause of `block/1`. What blocks show
  besides their own fields (files, products, categories) comes in the
  `data` map from `MercatorWeb.BlockData.load/1`; missing things are left
  out.
  """
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext

  import MercatorWeb.MarkdownComponents, only: [markdown: 1]
  import MercatorWeb.CoreComponents, only: [icon: 1]
  import MercatorWeb.CatalogComponents, only: [product_card: 1, category_tile: 1]

  alias Mercator.Content.{Asset, Blocks}
  alias Mercator.Translated
  alias Phoenix.LiveView.JS

  attr :block, Ash.Union, required: true
  attr :locale, :string, required: true
  attr :data, :map, default: %{}, doc: "from MercatorWeb.BlockData.load/1"

  def block(%{block: %Ash.Union{value: value}, data: data} = assigns) do
    assigns
    |> assign(:b, value)
    |> assign(:assets, Map.get(data, :assets, %{}))
    |> render_block()
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

  defp render_block(%{b: %Blocks.Products{}} = assigns) do
    assigns = assign(assigns, :entries, get_in(assigns.data, [:products, assigns.b.id]) || [])

    ~H"""
    <section :if={@entries != []} class="space-y-4" id={"block-#{@b.id}"}>
      <h2 :if={t(@b.heading, @locale)} class="text-2xl font-bold">{t(@b.heading, @locale)}</h2>
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div :for={{product, price} <- @entries} class="flex">
          <.product_card product={product} price={price} locale={@locale} />
        </div>
      </div>
    </section>
    """
  end

  defp render_block(%{b: %Blocks.Categories{}} = assigns) do
    assigns =
      assign(assigns, :categories, get_in(assigns.data, [:categories, assigns.b.id]) || [])

    ~H"""
    <section :if={@categories != []} class="space-y-4" id={"block-#{@b.id}"}>
      <h2 :if={t(@b.heading, @locale)} class="text-2xl font-bold">{t(@b.heading, @locale)}</h2>
      <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
        <.category_tile :for={category <- @categories} category={category} locale={@locale} />
      </div>
    </section>
    """
  end

  defp render_block(%{b: %Blocks.Columns{}} = assigns) do
    ~H"""
    <section
      class={[
        "grid gap-6",
        length(@b.items) == 2 && "md:grid-cols-2",
        length(@b.items) == 3 && "md:grid-cols-3",
        length(@b.items) >= 4 && "md:grid-cols-2 lg:grid-cols-4"
      ]}
      id={"block-#{@b.id}"}
    >
      <div :for={item <- @b.items} class="space-y-2">
        <h3 :if={t(item.title, @locale)} class="text-lg font-semibold">{t(item.title, @locale)}</h3>
        <.markdown text={t(item.text, @locale)} />
      </div>
    </section>
    """
  end

  defp render_block(%{b: %Blocks.Faq{}} = assigns) do
    ~H"""
    <section class="max-w-3xl space-y-3" id={"block-#{@b.id}"}>
      <h2 :if={t(@b.heading, @locale)} class="text-2xl font-bold">{t(@b.heading, @locale)}</h2>
      <details
        :for={item <- @b.items}
        class="collapse collapse-arrow bg-base-100 shadow-sm"
        id={"faq-#{item.id}"}
      >
        <summary class="collapse-title font-semibold">{t(item.question, @locale)}</summary>
        <div class="collapse-content">
          <.markdown text={t(item.answer, @locale)} />
        </div>
      </details>
    </section>
    """
  end

  defp render_block(%{b: %Blocks.Shared{}} = assigns) do
    assigns = assign(assigns, :shared, get_in(assigns.data, [:shared, assigns.b.id]))

    ~H"""
    <div :if={@shared} class="space-y-8" id={"block-#{@b.id}"}>
      <.block
        :for={block <- elem(@shared, 0)}
        block={block}
        locale={@locale}
        data={Map.merge(elem(@shared, 1), Map.take(@data, [:page_id, :client_ip, :available?]))}
      />
    </div>
    """
  end

  defp render_block(%{b: %Blocks.ContactForm{}} = assigns) do
    ~H"""
    <.live_component
      module={MercatorWeb.ContactFormComponent}
      id={"block-#{@b.id}"}
      block={@b}
      locale={@locale}
      page_id={@data[:page_id]}
      client_ip={@data[:client_ip]}
    />
    """
  end

  defp render_block(%{b: %Blocks.CallToAction{}} = assigns) do
    ~H"""
    <section
      class="flex flex-col items-start gap-4 rounded-box bg-primary p-8 text-primary-content md:flex-row md:items-center"
      id={"block-#{@b.id}"}
    >
      <div class="flex-1 space-y-2">
        <h2 :if={t(@b.headline, @locale)} class="text-2xl font-bold">{t(@b.headline, @locale)}</h2>
        <.markdown text={t(@b.text, @locale)} />
      </div>
      <a
        :if={t(@b.button_label, @locale) && @b.button_link}
        href={@b.button_link}
        class="btn btn-lg"
      >
        {t(@b.button_label, @locale)}
      </a>
    </section>
    """
  end

  # #154: writing and talking open the chat widget (MercatorWeb.ChatLive);
  # `available?` (#156) is unknown (nil) in the editor's preview
  defp render_block(%{b: %Blocks.ContactOptions{}} = assigns) do
    phone = assigns.b.show_phone && Mercator.Brand.get(:phone)

    assigns =
      assigns
      |> assign(:available?, assigns.data[:available?])
      |> assign(:phone, phone)
      |> assign(:ways, 2 + Enum.count([assigns.b.message_link, phone], & &1))

    ~H"""
    <section class="space-y-6 rounded-box bg-base-200 p-6 md:p-8" id={"block-#{@b.id}"}>
      <div class="space-y-2">
        <h2 :if={t(@b.headline, @locale)} class="text-2xl font-bold">{t(@b.headline, @locale)}</h2>
        <.markdown text={t(@b.text, @locale)} />
        <p
          :if={is_boolean(@available?)}
          class="flex items-center gap-2 text-sm font-medium"
          id={"block-#{@b.id}-availability"}
          data-available={to_string(@available?)}
        >
          <span class={[
            "inline-block size-2.5 rounded-full",
            if(@available?, do: "bg-success animate-pulse", else: "bg-base-content/30")
          ]}></span>
          {if @available?,
            do: gettext("Our consultants are available now"),
            else: gettext("Nobody available right now – we will get back to you")}
        </p>
      </div>
      <div class={[
        "grid gap-4",
        case @ways do
          2 -> "sm:grid-cols-2"
          3 -> "md:grid-cols-3"
          _four -> "sm:grid-cols-2 lg:grid-cols-4"
        end
      ]}>
        <.contact_way
          icon="hero-chat-bubble-left-right"
          title={gettext("Write")}
          text={
            if @available? == false,
              do: gettext("Ask in the chat; we answer as soon as we are back."),
              else: gettext("Ask in the chat and get an answer right away.")
          }
          id={"block-#{@b.id}-write"}
        >
          <button
            type="button"
            phx-click={JS.dispatch("mercator:open-chat", detail: %{start: "write"})}
            class="btn btn-primary"
          >
            {gettext("Start chat")}
          </button>
        </.contact_way>
        <.contact_way
          icon="hero-phone"
          title={gettext("Talk")}
          text={
            if @available? == false,
              do: gettext("Leave your number and we will call you back."),
              else: gettext("A consultant calls you here in the browser; video only if you like.")
          }
          id={"block-#{@b.id}-call"}
        >
          <button
            type="button"
            phx-click={JS.dispatch("mercator:open-chat", detail: %{start: "call"})}
            class="btn btn-primary"
          >
            {if @available? == false, do: gettext("Request a callback"), else: gettext("Call me")}
          </button>
        </.contact_way>
        <.contact_way
          :if={@b.message_link}
          icon="hero-envelope"
          title={gettext("Message")}
          text={gettext("Send us your question; we answer by email.")}
          id={"block-#{@b.id}-message"}
        >
          <a href={@b.message_link} class="btn btn-outline">{gettext("Write a message")}</a>
        </.contact_way>
        <.contact_way
          :if={@phone}
          icon="hero-device-phone-mobile"
          title={gettext("Phone")}
          text={gettext("Call us during our opening hours.")}
          id={"block-#{@b.id}-phone"}
        >
          <a href={"tel:" <> String.replace(@phone, ~r/[^\d+]/, "")} class="btn btn-outline">
            {@phone}
          </a>
        </.contact_way>
      </div>
    </section>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, required: true
  attr :id, :string, required: true
  slot :inner_block, required: true

  defp contact_way(assigns) do
    ~H"""
    <div
      class="flex flex-col gap-3 rounded-box bg-base-100 p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
      id={@id}
    >
      <span class="flex size-11 items-center justify-center rounded-full bg-primary/10 text-primary">
        <.icon name={@icon} class="size-6" />
      </span>
      <h3 class="text-lg font-semibold">{@title}</h3>
      <p class="flex-1 text-sm text-base-content/70">{@text}</p>
      <div>{render_slot(@inner_block)}</div>
    </div>
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
