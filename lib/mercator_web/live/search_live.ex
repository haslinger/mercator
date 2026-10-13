defmodule MercatorWeb.SearchLive do
  @moduledoc "Product search page: `/suche?q=…` (decision #56)."
  use MercatorWeb, :live_view

  import MercatorWeb.CatalogComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.Listing

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Search"))
     |> stream_configure(:results, dom_id: fn {product, _price} -> "result-#{product.id}" end)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = String.trim(params["q"] || "")

    results =
      if query == "" do
        []
      else
        query
        |> Catalog.search_products!(actor: socket.assigns.current_user, load: Listing.loads())
        |> Enum.map(&{&1, from_price(&1)})
      end

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:count, length(results))
     |> stream(:results, results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/suche?#{[q: query]}")}
  end

  defp from_price(product) do
    case Catalog.from_price(product) do
      {:ok, info} -> info
      {:error, _} -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav_categories={@nav_categories}
      basket_count={@basket_count}
    >
      <h1 class="text-3xl font-bold">{gettext("Search")}</h1>

      <form id="search-form" phx-change="search" phx-submit="search" class="max-w-xl">
        <label class="input w-full">
          <.icon name="hero-magnifying-glass" class="size-5 opacity-50" />
          <input
            type="search"
            name="q"
            value={@query}
            placeholder={gettext("Search products or article numbers")}
            phx-debounce="300"
            autofocus
            id="search-input"
          />
        </label>
      </form>

      <p :if={@query != ""} class="text-sm text-base-content/70" id="result-count">
        {ngettext("1 result for “%{query}”", "%{count} results for “%{query}”", @count, query: @query)}
      </p>

      <div
        id="results"
        phx-update="stream"
        class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4"
      >
        <div class="hidden only:block text-base-content/70" id="no-results">
          {if @query == "",
            do: gettext("What are you looking for?"),
            else: gettext("No products found.")}
        </div>
        <div :for={{dom_id, {product, price}} <- @streams.results} id={dom_id} class="flex">
          <.product_card product={product} price={price} locale={@locale} />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
