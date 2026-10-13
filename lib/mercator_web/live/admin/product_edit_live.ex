defmodule MercatorWeb.Admin.ProductEditLive do
  @moduledoc """
  Product editor (back office step 4) with tabs. This module holds the frame
  (header, state, tabs) and the "general" tab: texts, highlights, master
  data and categories.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.TranslatedComponents

  alias Mercator.Catalog
  alias Mercator.Translated
  alias MercatorWeb.Admin.ProductIndexLive

  on_mount {MercatorWeb.LiveUserAuth, {:require_any_role, [:productmanager, :administrator]}}

  @tabs ~w(general variants images properties relations configurator)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns.current_user

    case Catalog.get_product(id, actor: actor, load: [:categories, :variants]) do
      {:ok, product} ->
        {:ok,
         socket
         |> assign(:product, product)
         |> assign(:page_title, Translated.t(product.title, socket.assigns.locale))
         |> assign(
           :categories,
           Catalog.list_categories!(actor: actor, query: [sort: [path: :asc]])
         )
         |> assign(
           :tax_classes,
           Catalog.list_tax_classes!(actor: actor, query: [sort: [position: :asc]])
         )
         |> assign_general_form()}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Product not found."))
         |> push_navigate(to: ~p"/admin/products")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = if params["tab"] in @tabs, do: params["tab"], else: "general"
    {:noreply, assign(socket, :tab, tab)}
  end

  defp assign_general_form(socket) do
    product = socket.assigns.product
    form = Catalog.form_to_update_product(product, actor: socket.assigns.current_user)

    socket
    |> assign(:form, to_form(form))
    |> assign(:highlights, highlights_text(product.highlights))
    |> assign(:category_ids, Enum.map(product.categories, & &1.id))
  end

  # highlights are edited as one textarea per locale, one highlight per line
  defp highlights_text(highlights) do
    Map.new(Translated.locales(), fn locale ->
      {locale, Enum.map_join(highlights, "\n", &(&1[locale] || ""))}
    end)
  end

  defp highlights_param(text_by_locale) do
    lines =
      Map.new(text_by_locale, fn {locale, text} -> {locale, String.split(text || "", "\n")} end)

    count = lines |> Map.values() |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)

    for index <- 0..(count - 1)//1,
        entry =
          Map.new(lines, fn {locale, list} ->
            {locale, String.trim(Enum.at(list, index) || "")}
          end),
        Enum.any?(entry, fn {_locale, text} -> text != "" end),
        do: entry
  end

  # --- events ---

  @impl true
  def handle_event("validate", %{"form" => params} = all, socket) do
    {:noreply,
     socket
     |> assign(:form, AshPhoenix.Form.validate(socket.assigns.form, params))
     |> assign(:highlights, all["highlights"] || socket.assigns.highlights)
     |> assign(
       :category_ids,
       Map.get(all, "category_ids", socket.assigns.category_ids) |> List.wrap()
     )}
  end

  def handle_event("save", %{"form" => params} = all, socket) do
    actor = socket.assigns.current_user
    params = Map.put(params, "highlights", highlights_param(all["highlights"] || %{}))
    category_ids = all |> Map.get("category_ids", []) |> List.wrap() |> Enum.reject(&(&1 == ""))

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, product} ->
        :ok = Catalog.set_product_categories(product, category_ids, actor)
        product = Catalog.get_product!(product.id, actor: actor, load: [:categories, :variants])

        {:noreply,
         socket
         |> assign(:product, product)
         |> assign_general_form()
         |> put_flash(:info, gettext("Product saved."))}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("transition", %{"to" => to}, socket) do
    actor = socket.assigns.current_user
    product = socket.assigns.product

    result =
      case to do
        "active" -> Catalog.activate_product(product, actor: actor)
        "discontinued" -> Catalog.discontinue_product(product, actor: actor)
      end

    case result do
      {:ok, updated} ->
        {:noreply, assign(socket, :product, %{product | state: updated.state})}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("A product needs at least one variant to be activated.")
         )}
    end
  end

  # flash messages from the tab components
  @impl true
  def handle_info({:flash, kind, message}, socket),
    do: {:noreply, put_flash(socket, kind, message)}

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="products">
      <.link navigate={~p"/admin/products"} class="link link-hover text-sm" id="back-to-products">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("Products")}
      </.link>

      <div class="flex flex-wrap items-center gap-3">
        <h1 class="text-3xl font-bold" id="product-title">{Translated.t(@product.title, @locale)}</h1>
        <ProductIndexLive.state_badge state={@product.state} />
        <span class="font-mono text-sm text-base-content/60">{@product.number}</span>
        <div class="ml-auto flex gap-2">
          <button
            :if={@product.state != :active}
            type="button"
            phx-click="transition"
            phx-value-to="active"
            class="btn btn-success btn-sm"
            id="activate-product"
          >
            {gettext("Activate")}
          </button>
          <button
            :if={@product.state == :active}
            type="button"
            phx-click="transition"
            phx-value-to="discontinued"
            data-confirm={
              gettext("Discontinue this product? It will no longer be shown in the shop.")
            }
            class="btn btn-sm"
            id="discontinue-product"
          >
            {gettext("Discontinue")}
          </button>
          <.link
            :if={@product.state == :active}
            navigate={~p"/produkte/#{@product.slug}"}
            class="btn btn-ghost btn-sm"
            id="view-in-shop"
          >
            <.icon name="hero-eye" class="size-4" /> {gettext("View in shop")}
          </.link>
        </div>
      </div>

      <div role="tablist" class="tabs tabs-border" id="product-tabs">
        <.link
          :for={{tab, label} <- tabs(@product)}
          patch={~p"/admin/products/#{@product.id}?tab=#{tab}"}
          role="tab"
          class={["tab", @tab == tab && "tab-active"]}
          id={"tab-#{tab}"}
        >
          {label}
        </.link>
      </div>

      <.general_tab
        :if={@tab == "general"}
        form={@form}
        highlights={@highlights}
        categories={@categories}
        category_ids={@category_ids}
        tax_classes={@tax_classes}
        locale={@locale}
      />

      <.live_component
        :if={@tab == "variants"}
        module={MercatorWeb.Admin.ProductVariantsTab}
        id="variants-tab"
        product_id={@product.id}
        current_user={@current_user}
        locale={@locale}
      />

      <.live_component
        :if={@tab == "images"}
        module={MercatorWeb.Admin.ProductImagesTab}
        id="images-tab"
        product_id={@product.id}
        current_user={@current_user}
        locale={@locale}
      />

      <.live_component
        :if={@tab == "properties"}
        module={MercatorWeb.Admin.ProductPropertiesTab}
        id="properties-tab"
        product_id={@product.id}
        current_user={@current_user}
        locale={@locale}
      />

      <.live_component
        :if={@tab == "relations"}
        module={MercatorWeb.Admin.ProductRelationsTab}
        id="relations-tab"
        product_id={@product.id}
        current_user={@current_user}
        locale={@locale}
      />

      <.live_component
        :if={@tab == "configurator"}
        module={MercatorWeb.Admin.ProductConfiguratorTab}
        id="configurator-tab"
        product_id={@product.id}
        current_user={@current_user}
        locale={@locale}
      />
    </Layouts.admin>
    """
  end

  defp tabs(%{kind: :configurable}), do: all_tabs()
  defp tabs(_product), do: Enum.reject(all_tabs(), &(elem(&1, 0) == "configurator"))

  defp all_tabs,
    do: [
      {"general", gettext("General")},
      {"variants", gettext("Variants & prices")},
      {"images", gettext("Images")},
      {"properties", gettext("Properties")},
      {"relations", gettext("Relations")},
      {"configurator", gettext("Configurator")}
    ]

  attr :form, :any, required: true
  attr :highlights, :map, required: true
  attr :categories, :list, required: true
  attr :category_ids, :list, required: true
  attr :tax_classes, :list, required: true
  attr :locale, :string, required: true

  defp general_tab(assigns) do
    ~H"""
    <.form for={@form} id="product-form" phx-change="validate" phx-submit="save" class="space-y-4">
      <div class="grid gap-4 lg:grid-cols-3">
        <section class="card bg-base-100 shadow-sm lg:col-span-2">
          <div class="card-body">
            <h2 class="card-title">{gettext("Texts")}</h2>
            <.translated_input field={@form[:title]} label={gettext("Title")} />
            <.translated_input field={@form[:subtitle]} label={gettext("Subtitle")} />
            <.translated_input
              field={@form[:description]}
              label={gettext("Description")}
              type="textarea"
              rows="3"
            />
            <.translated_input
              field={@form[:long_description]}
              label={gettext("Long description")}
              type="textarea"
              rows="5"
            />
            <.translated_input
              field={@form[:warranty]}
              label={gettext("Warranty")}
              type="textarea"
              rows="2"
            />
            <fieldset class="fieldset" id="highlights-fields">
              <legend class="fieldset-legend">{gettext("Highlights (one per line)")}</legend>
              <div class="grid gap-2 sm:grid-cols-2">
                <textarea
                  :for={{locale, text} <- Enum.sort(@highlights)}
                  name={"highlights[#{locale}]"}
                  rows="4"
                  class="textarea w-full"
                  placeholder={String.upcase(locale)}
                  id={"highlights-#{locale}"}
                >{text}</textarea>
              </div>
            </fieldset>
          </div>
        </section>

        <div class="space-y-4">
          <section class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h2 class="card-title">{gettext("Master data")}</h2>
              <.input field={@form[:number]} label={gettext("Article no.")} />
              <.input field={@form[:slug]} label={gettext("URL name (slug)")} />
              <.input
                field={@form[:kind]}
                type="select"
                label={gettext("Kind")}
                options={
                  Enum.map(~w(simple variants configurable)a, &{ProductIndexLive.kind_label(&1), &1})
                }
              />
              <.input
                field={@form[:tax_class_id]}
                type="select"
                label={gettext("Tax class")}
                options={Enum.map(@tax_classes, &{Translated.t(&1.name, @locale), &1.id})}
              />
              <.input
                field={@form[:shipping]}
                type="select"
                label={gettext("Shipping")}
                options={shipping_options()}
              />
              <.input field={@form[:new_arrival]} type="checkbox" label={gettext("New")} />
              <.input field={@form[:bestseller]} type="checkbox" label={gettext("Bestseller")} />
            </div>
          </section>

          <section class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h2 class="card-title">{gettext("Categories")}</h2>
              <input type="hidden" name="category_ids[]" value="" />
              <div class="max-h-80 overflow-y-auto" id="category-checkboxes">
                <label
                  :for={category <- @categories}
                  class="label flex text-base-content"
                  style={"padding-left: #{(length(category.path) - 1) * 1.25}rem"}
                >
                  <input
                    type="checkbox"
                    name="category_ids[]"
                    value={category.id}
                    checked={category.id in @category_ids}
                    class="checkbox checkbox-sm"
                    id={"product-category-#{category.id}"}
                  />
                  {Translated.t(category.name, @locale)}
                </label>
              </div>
            </div>
          </section>
        </div>
      </div>

      <div class="flex justify-end">
        <button type="submit" class="btn btn-primary" id="save-product">{gettext("Save")}</button>
      </div>
    </.form>
    """
  end

  defp shipping_options do
    [
      {gettext("Parcel"), :parcel},
      {gettext("Freight"), :freight},
      {gettext("Pickup only"), :pickup_only},
      {gettext("No shipping (service)"), :none}
    ]
  end
end
