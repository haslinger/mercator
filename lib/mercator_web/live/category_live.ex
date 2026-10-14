defmodule MercatorWeb.CategoryLive do
  @moduledoc """
  Category page: breadcrumb, subcategories and the products of the category
  and all its descendants, with filters and sorting kept in the URL.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.MarkdownComponents, only: [markdown: 1]

  import MercatorWeb.CatalogComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.Listing
  alias Mercator.Translated

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @sorts ~w(position price_asc price_desc name newest)

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    actor = socket.assigns.current_user

    case Catalog.get_category_by_slug(slug, actor: actor) do
      {:ok, category} ->
        subtree_ids = Enum.map(Catalog.list_category_subtree!(category.id, actor: actor), & &1.id)

        products =
          Catalog.list_products_in_categories!(subtree_ids, actor: actor, load: Listing.loads())

        {:ok,
         socket
         |> assign(:page_title, Translated.t(category.name, socket.assigns.locale))
         |> assign(:category, category)
         |> assign(:ancestors, Catalog.list_category_ancestors!(category.id, actor: actor))
         |> assign(:children, active_children(category, actor))
         |> assign(:products, products)
         |> stream_configure(:entries,
           dom_id: fn {product, _price} -> "product-#{product.id}" end
         )}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Category not found."))
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    params = Map.take(params, ["min", "max", "p", "new", "bestseller", "sale", "sort"])
    listing = Listing.build(socket.assigns.products, params, socket.assigns.locale)

    {:noreply,
     socket
     |> assign(:params, params)
     |> assign(:listing, Map.delete(listing, :entries))
     |> stream(:entries, listing.entries, reset: true)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query =
      params
      |> Map.take(["min", "max", "p", "new", "bestseller", "sale", "sort"])
      |> clean()

    {:noreply, push_patch(socket, to: ~p"/categories/#{socket.assigns.category.slug}?#{query}")}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/categories/#{socket.assigns.category.slug}")}
  end

  # drop empty values, so URLs stay short
  defp clean(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, clean(v)} end)
    |> Enum.reject(fn {k, v} ->
      v in [nil, "", [], %{}, "false"] or (k == "sort" and v == "position")
    end)
    |> Map.new()
  end

  defp clean(list) when is_list(list), do: Enum.reject(list, &(&1 in ["", "false"]))
  defp clean(value), do: value

  defp active_children(category, actor) do
    category.id
    |> Catalog.list_child_categories!(actor: actor, load: :images)
    |> Enum.filter(&(&1.state == :active))
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :sorts, @sorts)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav_categories={@nav_categories}
      basket_count={@basket_count}
    >
      <.breadcrumb items={
        Enum.map(@ancestors, &{Translated.t(&1.name, @locale), ~p"/categories/#{&1.slug}"}) ++
          [{Translated.t(@category.name, @locale), nil}]
      } />

      <div>
        <h1 class="text-3xl font-bold" id="category-name">{Translated.t(@category.name, @locale)}</h1>
        <p :if={@category.description} class="mt-2 text-base-content/80">
          {Translated.t(@category.description, @locale)}
        </p>
      </div>

      <div :if={@children != []} class="grid grid-cols-2 gap-4 md:grid-cols-4" id="subcategories">
        <.category_tile :for={child <- @children} category={child} locale={@locale} />
      </div>

      <div class="grid gap-6 lg:grid-cols-[16rem_1fr]">
        <.filters listing={@listing} params={@params} locale={@locale} sorts={@sorts} />

        <section>
          <p class="mb-3 text-sm text-base-content/70" id="product-count">
            {gettext("%{count} of %{total} products", count: @listing.count, total: @listing.total)}
          </p>
          <div
            id="products"
            phx-update="stream"
            class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3"
          >
            <div class="hidden only:block text-base-content/70" id="no-products">
              {gettext("No products match the selected filters.")}
            </div>
            <div :for={{dom_id, {product, price}} <- @streams.entries} id={dom_id} class="flex">
              <.product_card product={product} price={price} locale={@locale} />
            </div>
          </div>
        </section>
      </div>

      <div :if={@category.long_description} class="max-w-3xl" id="category-text">
        <.markdown text={Translated.t(@category.long_description, @locale)} heading_offset={1} />
      </div>
    </Layouts.app>
    """
  end

  attr :listing, :map, required: true
  attr :params, :map, required: true
  attr :locale, :string, required: true
  attr :sorts, :list, required: true

  defp filters(assigns) do
    ~H"""
    <aside>
      <form id="filter-form" phx-change="filter" phx-submit="filter" class="space-y-4">
        <fieldset class="fieldset">
          <legend class="fieldset-legend">{gettext("Sort by")}</legend>
          <select name="sort" class="select select-sm w-full" id="sort">
            <option :for={sort <- @sorts} value={sort} selected={@params["sort"] == sort}>
              {sort_label(sort)}
            </option>
          </select>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">{gettext("Price")}</legend>
          <div class="flex gap-2">
            <input
              type="number"
              name="min"
              min="0"
              step="any"
              value={@params["min"]}
              placeholder={gettext("from")}
              class="input input-sm w-full"
              id="price-min"
              phx-debounce="500"
            />
            <input
              type="number"
              name="max"
              min="0"
              step="any"
              value={@params["max"]}
              placeholder={gettext("to")}
              class="input input-sm w-full"
              id="price-max"
              phx-debounce="500"
            />
          </div>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">{gettext("Show only")}</legend>
          <label :for={{flag, label} <- flags()} class="label text-base-content">
            <input type="hidden" name={flag} value="false" />
            <input
              type="checkbox"
              name={flag}
              value="1"
              checked={@params[flag] == "1"}
              class="checkbox checkbox-sm"
              id={"flag-#{flag}"}
            />
            {label}
          </label>
        </fieldset>

        <fieldset :for={facet <- @listing.facets} class="fieldset" id={"facet-#{facet.property.id}"}>
          <legend class="fieldset-legend">{Translated.t(facet.property.name, @locale)}</legend>
          <input type="hidden" name={"p[#{facet.property.id}][]"} value="" />
          <label :for={{key, label, count} <- facet.values} class="label text-base-content">
            <input
              type="checkbox"
              name={"p[#{facet.property.id}][]"}
              value={key}
              checked={key in List.wrap(get_in(@params, ["p", facet.property.id]) || [])}
              class="checkbox checkbox-sm"
            />
            {label} <span class="text-base-content/50">({count})</span>
          </label>
        </fieldset>

        <button
          type="button"
          phx-click="reset_filters"
          class="btn btn-ghost btn-sm"
          id="reset-filters"
        >
          {gettext("Reset filters")}
        </button>
      </form>
    </aside>
    """
  end

  defp flags do
    [{"new", gettext("New")}, {"bestseller", gettext("Bestseller")}, {"sale", gettext("Sale")}]
  end

  defp sort_label("position"), do: gettext("Recommended")
  defp sort_label("price_asc"), do: gettext("Price, low to high")
  defp sort_label("price_desc"), do: gettext("Price, high to low")
  defp sort_label("name"), do: gettext("Name")
  defp sort_label("newest"), do: gettext("Newest")
end
