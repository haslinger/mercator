defmodule MercatorWeb.CatalogComponents do
  @moduledoc """
  Components for catalogue pages: breadcrumb, category tiles, product cards,
  prices, badges and image placeholders.
  """
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: MercatorWeb.Endpoint,
    router: MercatorWeb.Router,
    statics: MercatorWeb.static_paths()

  import MercatorWeb.CoreComponents, only: [icon: 1]

  alias Mercator.Catalog.Listing
  alias Mercator.Translated
  alias MercatorWeb.Format

  attr :items, :list,
    required: true,
    doc: "list of {label, path}; the last one is the current page"

  def breadcrumb(assigns) do
    ~H"""
    <div class="breadcrumbs text-sm" id="breadcrumb">
      <ul>
        <li><.link navigate={~p"/"}>{gettext("Home")}</.link></li>
        <li :for={{label, path} <- @items}>
          <.link :if={path} navigate={path}>{label}</.link>
          <span :if={!path}>{label}</span>
        </li>
      </ul>
    </div>
    """
  end

  attr :category, :map, required: true
  attr :locale, :string, required: true

  def category_tile(assigns) do
    ~H"""
    <.link
      navigate={~p"/categories/#{@category.slug}"}
      class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow"
      id={"category-tile-#{@category.slug}"}
    >
      <.catalog_image
        image={first_image(@category)}
        label={Translated.t(@category.name, @locale)}
        class="h-40 rounded-t-box"
      />
      <div class="card-body p-4">
        <h3 class="font-semibold">{Translated.t(@category.name, @locale)}</h3>
        <p :if={@category.description} class="text-sm text-base-content/70 line-clamp-2">
          {Translated.t(@category.description, @locale)}
        </p>
      </div>
    </.link>
    """
  end

  attr :product, :map, required: true
  attr :price, :any, required: true, doc: "PriceInfo of the from price, or nil"
  attr :locale, :string, required: true

  def product_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/products/#{@product.slug}"}
      class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow"
      id={"product-card-#{@product.slug}"}
    >
      <div class="relative">
        <.catalog_image
          image={first_image(@product)}
          label={Translated.t(@product.title, @locale)}
          class="h-48 rounded-t-box"
        />
        <div class="absolute top-2 left-2"><.badges product={@product} price={@price} /></div>
      </div>
      <div class="card-body p-4 gap-1">
        <h3 class="font-semibold leading-snug">{Translated.t(@product.title, @locale)}</h3>
        <p :if={@product.subtitle} class="text-sm text-base-content/70">
          {Translated.t(@product.subtitle, @locale)}
        </p>
        <div class="mt-auto pt-2">
          <.price
            :if={@price}
            price={@price}
            locale={@locale}
            from={@product.kind == :configurable or length(@product.variants) > 1}
          />
          <span :if={!@price} class="text-sm text-base-content/60">{gettext("Price on request")}</span>
        </div>
      </div>
    </.link>
    """
  end

  attr :price, :map, required: true
  attr :locale, :string, required: true
  attr :from, :boolean, default: false
  attr :unit, :atom, default: nil
  attr :size, :string, default: "md", values: ~w(md lg)

  @doc "A unit price, gross or net per shop setting, with the regular price crossed out for promotions."
  def price(assigns) do
    assigns =
      assigns
      |> assign(:amount, Listing.display_price(assigns.price))
      |> assign(:regular, regular(assigns.price))
      |> assign(:gross?, Listing.display_gross?())

    ~H"""
    <div class="flex flex-wrap items-baseline gap-x-2" data-role="price">
      <span :if={@from} class="text-sm">{gettext("from")}</span>
      <span class={[
        "font-bold",
        @size == "lg" && "text-3xl",
        @size == "md" && "text-lg",
        @price.promotion? && "text-error"
      ]}>
        {Format.money(@amount, @locale)}
      </span>
      <span :if={@unit} class="text-sm text-base-content/70">{Format.per_unit(@unit)}</span>
      <s :if={@regular} class="text-sm text-base-content/60">{Format.money(@regular, @locale)}</s>
    </div>
    <p :if={@size == "lg"} class="text-xs text-base-content/60">
      <%= if @gross? do %>
        {gettext("incl. %{rate} % VAT", rate: Format.percent(@price.vat_rate))}
      <% else %>
        {gettext("excl. %{rate} % VAT", rate: Format.percent(@price.vat_rate))}
      <% end %>
    </p>
    """
  end

  defp regular(%{promotion?: true} = info) do
    if Listing.display_gross?(), do: info.regular_unit_gross, else: info.regular_unit_net
  end

  defp regular(_info), do: nil

  attr :product, :map, required: true
  attr :price, :any, default: nil

  def badges(assigns) do
    ~H"""
    <div class="flex gap-1">
      <span :if={@product.new_arrival} class="badge badge-secondary badge-sm">{gettext("New")}</span>
      <span :if={@product.bestseller} class="badge badge-accent badge-sm">{gettext("Bestseller")}</span>
      <span :if={@price && @price.promotion?} class="badge badge-error badge-sm">{gettext("Sale")}</span>
    </div>
    """
  end

  attr :image, :any, required: true, doc: "a Mercator.Catalog.Image or nil"
  attr :label, :string, required: true
  attr :size, :atom, default: :thumb, values: [:thumb, :large]
  attr :class, :any, default: nil

  @doc """
  An uploaded catalogue image, or the placeholder if there is none. Large
  images (top of the product page) load immediately, thumbnails lazily.
  """
  def catalog_image(%{image: nil} = assigns) do
    ~H"""
    <.placeholder_image label={@label} class={@class} />
    """
  end

  def catalog_image(assigns) do
    ~H"""
    <img
      src={Mercator.Catalog.Image.url(@image, @size)}
      alt={Translated.t(@image.alt, Gettext.get_locale(MercatorWeb.Gettext)) || @label}
      width={if @size == :thumb, do: 400, else: 1024}
      height={if @size == :thumb, do: 400, else: 1024}
      loading={if @size == :large, do: "eager", else: "lazy"}
      fetchpriority={if @size == :large, do: "high", else: "auto"}
      class={["w-full object-cover", @class]}
    />
    """
  end

  @doc "The first image of a product or category with loaded images, or nil."
  def first_image(%{images: [image | _]}), do: image
  def first_image(_record), do: nil

  attr :label, :string, required: true
  attr :class, :any, default: nil

  @doc "Placeholder for products and categories without images: a wood-toned area with an icon."
  def placeholder_image(assigns) do
    ~H"""
    <div
      class={[
        "flex items-center justify-center bg-gradient-to-br from-base-200 to-base-300 text-base-content/30",
        @class
      ]}
      role="img"
      aria-label={@label}
    >
      <.icon name="hero-photo" class="size-10" />
    </div>
    """
  end
end
