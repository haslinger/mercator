defmodule MercatorWeb.Admin.ProductIndexLive do
  @moduledoc """
  Product management, list (back office step 3): search, filters by category
  (including subcategories), state and kind; state changes; new products.

  Filtering happens in memory, fine for catalogues of a few thousand products.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.CatalogComponents, only: [catalog_image: 1, first_image: 1]
  import MercatorWeb.TranslatedComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.Listing
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, {:require_any_role, [:productmanager, :administrator]}}

  @filters ~w(q category state kind)

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, gettext("Products"))
     |> assign(:categories, Catalog.list_categories!(actor: actor, query: [sort: [path: :asc]]))
     |> assign(
       :tax_classes,
       Catalog.list_tax_classes!(actor: actor, query: [sort: [position: :asc]])
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = Map.take(params, @filters)

    socket =
      socket
      |> assign(:filters, filters)
      |> load_products(filters)

    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :new) do
    form = Catalog.form_to_create_product(actor: socket.assigns.current_user)
    assign(socket, :form, to_form(form))
  end

  defp apply_action(socket, _index), do: assign(socket, :form, nil)

  defp load_products(socket, filters) do
    actor = socket.assigns.current_user
    loads = [:categories | Listing.loads()]

    products =
      case String.trim(filters["q"] || "") do
        "" -> Catalog.list_products!(actor: actor, load: loads, query: [sort: [number: :asc]])
        q -> Catalog.search_products!(q, actor: actor, load: loads)
      end
      |> filter_state(filters["state"])
      |> filter_kind(filters["kind"])
      |> filter_category(filters["category"], socket)

    assign(socket, :products, Enum.map(products, &{&1, from_price(&1)}))
  end

  defp filter_state(products, state) when state in ~w(draft active discontinued),
    do: Enum.filter(products, &(to_string(&1.state) == state))

  defp filter_state(products, _state), do: products

  defp filter_kind(products, kind) when kind in ~w(simple variants configurable),
    do: Enum.filter(products, &(to_string(&1.kind) == kind))

  defp filter_kind(products, _kind), do: products

  defp filter_category(products, id, socket) when is_binary(id) and id != "" do
    ids =
      Catalog.list_category_subtree!(id, actor: socket.assigns.current_user)
      |> MapSet.new(& &1.id)

    Enum.filter(products, fn product ->
      Enum.any?(product.categories, &MapSet.member?(ids, &1.id))
    end)
  end

  defp filter_category(products, _id, _socket), do: products

  defp from_price(product) do
    case Catalog.from_price(product) do
      {:ok, info} -> info
      _ -> nil
    end
  end

  # --- events ---

  @impl true
  def handle_event("filter", params, socket) do
    query =
      params |> Map.take(@filters) |> Enum.reject(fn {_k, v} -> v in [nil, ""] end) |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/admin/products?#{query}")}
  end

  def handle_event("transition", %{"id" => id, "to" => to}, socket) do
    actor = socket.assigns.current_user
    product = Catalog.get_product!(id, actor: actor)

    result =
      case to do
        "active" -> Catalog.activate_product(product, actor: actor)
        "discontinued" -> Catalog.discontinue_product(product, actor: actor)
      end

    case result do
      {:ok, _} ->
        {:noreply, load_products(socket, socket.assigns.filters)}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("A product needs at least one variant to be activated.")
         )}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("create", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Product created. Add variants and prices next."))
         |> push_navigate(to: ~p"/admin/products/#{product.id}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
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
      active="products"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Products")}</h1>
        <.link patch={~p"/admin/products/new?#{@filters}"} class="btn btn-primary" id="new-product">
          <.icon name="hero-plus" class="size-5" /> {gettext("New product")}
        </.link>
      </div>

      <form id="product-filters" phx-change="filter" phx-submit="filter" class="flex flex-wrap gap-2">
        <label class="input input-sm w-64">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
          <input
            type="search"
            name="q"
            value={@filters["q"]}
            placeholder={gettext("Search products or article numbers")}
            phx-debounce="300"
            id="product-search"
          />
        </label>
        <select name="category" class="select select-sm w-56" id="filter-category">
          <option value="">{gettext("All categories")}</option>
          <option
            :for={category <- @categories}
            value={category.id}
            selected={@filters["category"] == category.id}
          >
            {String.duplicate("– ", length(category.path) - 1)}{Translated.t(category.name, @locale)}
          </option>
        </select>
        <select name="state" class="select select-sm w-40" id="filter-state">
          <option value="">{gettext("All states")}</option>
          <option
            :for={{value, label} <- states()}
            value={value}
            selected={@filters["state"] == value}
          >
            {label}
          </option>
        </select>
        <select name="kind" class="select select-sm w-44" id="filter-kind">
          <option value="">{gettext("All kinds")}</option>
          <option :for={{value, label} <- kinds()} value={value} selected={@filters["kind"] == value}>
            {label}
          </option>
        </select>
      </form>

      <p class="text-sm text-base-content/70" id="product-total">
        {ngettext("1 product", "%{count} products", length(@products))}
      </p>

      <div class="overflow-x-auto rounded-box bg-base-100 shadow-sm">
        <table class="table" id="products-table">
          <thead>
            <tr>
              <th class="w-16"></th>
              <th>{gettext("Article no.")}</th>
              <th>{gettext("Product")}</th>
              <th>{gettext("Kind")}</th>
              <th>{gettext("State")}</th>
              <th class="text-right">{gettext("Price")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{product, price} <- @products} id={"product-#{product.id}"} class="hover">
              <td>
                <.catalog_image
                  image={first_image(product)}
                  label={Translated.t(product.title, @locale)}
                  class="size-12 rounded"
                />
              </td>
              <td class="font-mono text-sm">{product.number}</td>
              <td>
                <.link
                  navigate={~p"/admin/products/#{product.id}"}
                  class="link link-hover font-medium"
                >
                  {Translated.t(product.title, @locale)}
                </.link>
                <div class="text-xs text-base-content/60">
                  {Enum.map_join(product.categories, ", ", &Translated.t(&1.name, @locale))}
                </div>
              </td>
              <td>{kind_label(product.kind)}</td>
              <td><.state_badge state={product.state} /></td>
              <td class="text-right whitespace-nowrap">
                {price && Format.money(Listing.display_price(price), @locale)}
              </td>
              <td class="text-right whitespace-nowrap">
                <button
                  :if={product.state != :active}
                  type="button"
                  phx-click="transition"
                  phx-value-id={product.id}
                  phx-value-to="active"
                  class="btn btn-ghost btn-xs"
                  id={"activate-#{product.id}"}
                >
                  {gettext("Activate")}
                </button>
                <button
                  :if={product.state == :active}
                  type="button"
                  phx-click="transition"
                  phx-value-id={product.id}
                  phx-value-to="discontinued"
                  data-confirm={
                    gettext("Discontinue this product? It will no longer be shown in the shop.")
                  }
                  class="btn btn-ghost btn-xs"
                  id={"discontinue-#{product.id}"}
                >
                  {gettext("Discontinue")}
                </button>
                <.link
                  :if={product.state == :active}
                  navigate={~p"/products/#{product.slug}"}
                  class="btn btn-ghost btn-xs"
                  title={gettext("View in shop")}
                >
                  <.icon name="hero-eye" class="size-4" />
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.new_product_form
        :if={@form}
        form={@form}
        tax_classes={@tax_classes}
        filters={@filters}
        locale={@locale}
      />
    </Layouts.admin>
    """
  end

  attr :form, :any, required: true
  attr :tax_classes, :list, required: true
  attr :filters, :map, required: true
  attr :locale, :string, required: true

  defp new_product_form(assigns) do
    ~H"""
    <div class="modal modal-open" id="new-product-modal">
      <div class="modal-box max-w-2xl">
        <h2 class="text-xl font-bold">{gettext("New product")}</h2>
        <.form
          for={@form}
          id="new-product-form"
          phx-change="validate"
          phx-submit="create"
          class="mt-4"
        >
          <.input field={@form[:number]} label={gettext("Article no.")} placeholder="BH-…" />
          <.translated_input field={@form[:title]} label={gettext("Title")} />
          <div class="grid gap-3 sm:grid-cols-2">
            <.input
              field={@form[:kind]}
              type="select"
              label={gettext("Kind")}
              options={Enum.map(kinds(), fn {value, label} -> {label, value} end)}
            />
            <.input
              field={@form[:tax_class_id]}
              type="select"
              label={gettext("Tax class")}
              options={Enum.map(@tax_classes, &{Translated.t(&1.name, @locale), &1.id})}
            />
          </div>
          <.input
            :if={to_string(@form[:kind].value) == "configurable"}
            field={@form[:pricing]}
            type="select"
            label={gettext("Pricing")}
            options={Enum.map(pricings(), fn {value, label} -> {label, value} end)}
          />
          <div class="modal-action">
            <.link patch={~p"/admin/products?#{@filters}"} class="btn btn-ghost">{gettext("Cancel")}</.link>
            <button type="submit" class="btn btn-primary" id="create-product">{gettext("Create")}</button>
          </div>
        </.form>
      </div>
      <.link patch={~p"/admin/products?#{@filters}"} class="modal-backdrop">{gettext("Close")}</.link>
    </div>
    """
  end

  attr :state, :atom, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @state == :active && "badge-success",
      @state == :discontinued && "badge-error badge-outline",
      @state == :draft && "badge-ghost"
    ]}>
      {state_label(@state)}
    </span>
    """
  end

  defp states, do: Enum.map(~w(draft active discontinued)a, &{to_string(&1), state_label(&1)})

  def state_label(:draft), do: gettext("Draft")
  def state_label(:active), do: gettext("Active")
  def state_label(:discontinued), do: gettext("Discontinued")

  defp kinds, do: Enum.map(~w(simple variants configurable)a, &{to_string(&1), kind_label(&1)})

  def kind_label(:simple), do: gettext("Simple")
  def kind_label(:variants), do: gettext("Variants")
  def kind_label(:configurable), do: gettext("Configurable")

  def pricings do
    [
      {"per_volume", gettext("per m³ (length × width × thickness)")},
      {"per_area", gettext("per m² (length × width)")},
      {"per_length", gettext("per running metre (length)")},
      {"per_unit", gettext("per piece")}
    ]
  end
end
