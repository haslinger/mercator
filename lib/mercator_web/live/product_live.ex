defmodule MercatorWeb.ProductLive do
  @moduledoc """
  Product page: variant selection, quantity with live price, graduated
  prices, highlights, description, properties and related products.
  Adding to the basket follows in phase 3.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.CatalogComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.{Listing, Unit}
  alias Mercator.Sales.Baskets
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @loads [
    :tax_class,
    :categories,
    :images,
    variants: :prices,
    options: :choices,
    product_properties: [property: :property_group],
    relations: [related_product: Listing.loads()]
  ]

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    actor = socket.assigns.current_user

    case Catalog.get_product_by_slug(slug, actor: actor, load: @loads) do
      {:ok, product} ->
        {:ok,
         socket
         |> assign(:page_title, Translated.t(product.title, socket.assigns.locale))
         |> assign(:product, product)
         |> assign(:trail, trail(product, actor))
         |> assign(:quantity, "1")
         |> assign(:quantity_error, nil)
         |> assign_configuration(product)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Product not found."))
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    variants = socket.assigns.product.variants
    variant = Enum.find(variants, &(&1.number == params["variant"])) || List.first(variants)

    {:noreply, socket |> assign(:variant, variant) |> calculate()}
  end

  @impl true
  def handle_event("select_variant", %{"variant" => number}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/produkte/#{socket.assigns.product.slug}?variant=#{number}")}
  end

  def handle_event("configure", params, socket) do
    selections = Map.merge(socket.assigns.selections, params["config"] || %{})
    quantity = params["quantity"] || socket.assigns.config_quantity

    {:noreply,
     socket
     |> assign(:selections, selections)
     |> assign(:config_quantity, quantity)
     |> recalculate()}
  end

  def handle_event("add_to_basket", _params, socket) do
    %{product: product, basket_owner: owner} = socket.assigns

    result =
      if product.kind == :configurable do
        Baskets.add(
          owner,
          hd(product.variants).id,
          socket.assigns.config_quantity,
          socket.assigns.selections
        )
      else
        Baskets.add(owner, socket.assigns.variant.id, socket.assigns.quantity)
      end

    case result do
      {:ok, _item} ->
        {:noreply,
         socket
         |> assign(:basket_count, Baskets.count(owner))
         |> put_flash(:info, gettext("Added to the basket."))}

      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("The item could not be added."))}
    end
  end

  def handle_event("quantity", %{"quantity" => quantity}, socket) do
    {:noreply, socket |> assign(:quantity, quantity) |> calculate()}
  end

  defp assign_configuration(socket, %{kind: :configurable} = product) do
    socket
    |> assign(:selections, Catalog.Configurator.defaults(product))
    |> assign(:config_quantity, "1")
    |> recalculate()
  end

  defp assign_configuration(socket, _product), do: assign(socket, quote: nil, config_errors: %{})

  defp recalculate(socket) do
    %{product: product, selections: selections, config_quantity: quantity} = socket.assigns

    case Catalog.quote(product, selections, quantity) do
      {:ok, quote} -> assign(socket, quote: quote, config_errors: %{})
      {:error, errors} -> assign(socket, config_errors: errors)
    end
  end

  # price of the selected variant for the entered quantity
  defp calculate(%{assigns: %{variant: nil}} = socket), do: assign(socket, :price, nil)

  defp calculate(socket) do
    %{variant: variant, quantity: quantity, product: product} = socket.assigns

    case parse_quantity(quantity, variant.unit) do
      {:ok, decimal} ->
        price =
          case Catalog.price_for(%{variant | product: product}, decimal) do
            {:ok, info} -> info
            {:error, _} -> nil
          end

        socket |> assign(:price, price) |> assign(:quantity_error, nil)

      {:error, message} ->
        assign(socket, :quantity_error, message)
    end
  end

  defp parse_quantity(input, unit) do
    with {decimal, ""} <- Decimal.parse(String.replace(input || "", ",", ".")),
         true <- Decimal.gt?(decimal, 0) do
      if Unit.decimals?(unit) or Decimal.integer?(decimal) do
        {:ok, decimal}
      else
        {:error, gettext("Please enter a whole number.")}
      end
    else
      _ -> {:error, gettext("Please enter a quantity greater than zero.")}
    end
  end

  # breadcrumb through the first category of the product
  defp trail(%{categories: [category | _]}, actor) do
    Catalog.list_category_ancestors!(category.id, actor: actor) ++ [category]
  end

  defp trail(_product, _actor), do: []

  defp can_add?(%{product: %{kind: :configurable}} = assigns),
    do: assigns.quote != nil and assigns.config_errors == %{}

  defp can_add?(assigns),
    do: assigns.variant != nil and assigns.price != nil and assigns.quantity_error == nil

  defp relations(product, kind), do: Enum.filter(product.relations, &(&1.kind == kind))

  defp from_price(product) do
    case Catalog.from_price(product) do
      {:ok, info} -> info
      _ -> nil
    end
  end

  defp property_groups(product) do
    product.product_properties
    |> Enum.group_by(& &1.property.property_group)
    |> Enum.sort_by(fn {group, _} -> group.position end)
    |> Enum.map(fn {group, values} -> {group, Enum.sort_by(values, & &1.property.position)} end)
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
      <.breadcrumb items={
        Enum.map(@trail, &{Translated.t(&1.name, @locale), ~p"/kategorien/#{&1.slug}"}) ++
          [{Translated.t(@product.title, @locale), nil}]
      } />

      <div class="grid gap-8 lg:grid-cols-2">
        <div id="gallery">
          <.catalog_image
            image={first_image(@product)}
            label={Translated.t(@product.title, @locale)}
            size={:large}
            class="aspect-square rounded-box"
          />
        </div>

        <div class="space-y-4">
          <.badges product={@product} price={@price} />
          <div>
            <h1 class="text-3xl font-bold" id="product-title">
              {Translated.t(@product.title, @locale)}
            </h1>
            <p :if={@product.subtitle} class="text-lg text-base-content/80">
              {Translated.t(@product.subtitle, @locale)}
            </p>
            <p class="text-sm text-base-content/60" id="article-number">
              {gettext("Article no.")} {@variant && @variant.number}
            </p>
          </div>

          <%= if @product.kind == :configurable do %>
            <.configurator
              product={@product}
              selections={@selections}
              quantity={@config_quantity}
              quote={@quote}
              errors={@config_errors}
              locale={@locale}
            />
          <% else %>
            <div :if={@variant} id="price-box" class="space-y-1">
              <.price :if={@price} price={@price} locale={@locale} unit={@variant.unit} size="lg" />
              <p :if={!@price} class="text-base-content/70">{gettext("Price on request")}</p>
              <p class="text-sm" id="delivery-time">
                <.icon name="hero-truck" class="size-4" />
                {Translated.t(@variant.delivery_time, @locale)}
              </p>
            </div>

            <div :if={length(@product.variants) > 1} id="variants">
              <p class="mb-2 font-semibold">{gettext("Variant")}</p>
              <div class="flex flex-wrap gap-2">
                <button
                  :for={variant <- @product.variants}
                  type="button"
                  phx-click="select_variant"
                  phx-value-variant={variant.number}
                  class={[
                    "btn btn-sm",
                    variant.id == @variant.id && "btn-primary",
                    variant.id != @variant.id && "btn-outline"
                  ]}
                  id={"variant-#{variant.number}"}
                >
                  {Translated.t(variant.name, @locale) || variant.number}
                </button>
              </div>
            </div>

            <form
              :if={@variant}
              id="quantity-form"
              phx-change="quantity"
              phx-submit="quantity"
              class="space-y-2"
            >
              <label class="fieldset">
                <span class="fieldset-legend">{gettext("Quantity")} ({Unit.label(@variant.unit)})</span>
                <input
                  type="text"
                  inputmode="decimal"
                  name="quantity"
                  value={@quantity}
                  class={["input w-40", @quantity_error && "input-error"]}
                  id="quantity"
                  phx-debounce="300"
                />
              </label>
              <p :if={@quantity_error} class="text-sm text-error" id="quantity-error">
                {@quantity_error}
              </p>
              <p :if={@price && !@quantity_error} class="text-lg" id="total">
                {gettext("Total")}:
                <strong>
                  {Format.money(
                    if(Listing.display_gross?(), do: @price.gross, else: @price.net),
                    @locale
                  )}
                </strong>
              </p>
            </form>

            <.graduated_prices :if={@variant} variant={@variant} product={@product} locale={@locale} />
          <% end %>

          <button
            type="button"
            phx-click="add_to_basket"
            class="btn btn-primary btn-lg"
            disabled={not can_add?(assigns)}
            id="add-to-basket"
          >
            <.icon name="hero-shopping-cart" class="size-5" /> {gettext("Add to basket")}
          </button>

          <ul :if={@product.highlights != []} class="list-disc pl-5" id="highlights">
            <li :for={highlight <- @product.highlights}>{Translated.t(highlight, @locale)}</li>
          </ul>
        </div>
      </div>

      <section
        :if={@product.description || @product.long_description}
        class="prose max-w-none"
        id="description"
      >
        <h2>{gettext("Description")}</h2>
        <p :if={@product.description}>{Translated.t(@product.description, @locale)}</p>
        <p :if={@product.long_description}>{Translated.t(@product.long_description, @locale)}</p>
      </section>

      <section :if={@product.product_properties != []} id="properties">
        <h2 class="mb-2 text-xl font-bold">{gettext("Properties")}</h2>
        <div class="overflow-x-auto rounded-box bg-base-100 shadow-sm">
          <table class="table">
            <tbody :for={{group, values} <- property_groups(@product)}>
              <tr class="bg-base-200">
                <th colspan="2">{Translated.t(group.name, @locale)}</th>
              </tr>
              <tr :for={value <- values}>
                <td class="w-1/3">{Translated.t(value.property.name, @locale)}</td>
                <td>{Listing.value_label(value, @locale)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <.related
        :for={
          {kind, title} <- [
            accessory: gettext("Matching accessories"),
            recommended: gettext("We recommend"),
            related: gettext("Similar products")
          ]
        }
        :if={relations(@product, kind) != []}
        id={"relations-#{kind}"}
        title={title}
        relations={relations(@product, kind)}
        locale={@locale}
      />
    </Layouts.app>
    """
  end

  attr :product, :map, required: true
  attr :selections, :map, required: true
  attr :quantity, :string, required: true
  attr :quote, :any, required: true
  attr :errors, :map, required: true
  attr :locale, :string, required: true

  # Configurable products (#55): options, dimensions, quantity and a live quote.
  defp configurator(assigns) do
    ~H"""
    <form id="configurator" phx-change="configure" phx-submit="configure" class="space-y-3">
      <div class="grid gap-3 sm:grid-cols-2">
        <label :for={option <- @product.options} class="fieldset" id={"option-#{option.key}"}>
          <span class="fieldset-legend">
            {Translated.t(option.name, @locale)}
            <span :if={option.kind == :number} class="font-normal text-base-content/60">
              ({range(option)})
            </span>
          </span>
          <%= if option.kind == :choice do %>
            <select name={"config[#{option.key}]"} class="select w-full" id={"config-#{option.key}"}>
              <option
                :for={choice <- option.choices}
                value={choice.key}
                selected={@selections[option.key] == choice.key}
              >
                {choice_label(choice, option, @product, @locale)}
              </option>
            </select>
          <% else %>
            <input
              type="number"
              name={"config[#{option.key}]"}
              value={@selections[option.key]}
              min={option.min && Decimal.to_string(option.min, :normal)}
              max={option.max && Decimal.to_string(option.max, :normal)}
              step={(option.step && Decimal.to_string(option.step, :normal)) || "any"}
              class={["input w-full", @errors[option.key] && "input-error"]}
              id={"config-#{option.key}"}
              phx-debounce="400"
            />
          <% end %>
          <span :if={@errors[option.key]} class="text-sm text-error">{@errors[option.key]}</span>
        </label>

        <label class="fieldset">
          <span class="fieldset-legend">{gettext("Quantity")} ({Unit.label(:piece)})</span>
          <input
            type="number"
            name="quantity"
            value={@quantity}
            min="1"
            step="1"
            class={["input w-full", @errors["quantity"] && "input-error"]}
            id="config-quantity"
            phx-debounce="400"
          />
          <span :if={@errors["quantity"]} class="text-sm text-error">{@errors["quantity"]}</span>
        </label>
      </div>
    </form>

    <div :if={@quote} class={["card bg-base-200", @errors != %{} && "opacity-50"]} id="quote">
      <div class="card-body gap-2 p-4">
        <p class="text-sm text-base-content/70" id="quote-measure">
          {gettext("%{measure} %{unit} per piece",
            measure: Format.quantity(@quote.measure, @quote.measure_unit, @locale),
            unit: Unit.symbol(@quote.measure_unit)
          )} · {gettext("Configuration no.")} <span id="config-number">{@quote.config_number}</span>
        </p>
        <table class="table table-sm">
          <thead>
            <tr>
              <th>{gettext("Calculation")}</th>
              <th class="text-right">{gettext("net")}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={line <- @quote.lines}>
              <td>{line_label(line, @quote, @locale)}</td>
              <td class="text-right">{Format.money(line.amount, @locale)}</td>
            </tr>
            <tr class="font-semibold">
              <td>{gettext("Net total")}</td>
              <td class="text-right">{Format.money(@quote.net, @locale)}</td>
            </tr>
            <tr>
              <td>{gettext("VAT %{rate} %", rate: Format.percent(@quote.vat_rate))}</td>
              <td class="text-right">{Format.money(@quote.vat, @locale)}</td>
            </tr>
            <tr class="text-lg font-bold">
              <td>{gettext("Total")}</td>
              <td class="text-right" id="quote-total">{Format.money(@quote.gross, @locale)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp range(option) do
    [option.min, option.max]
    |> Enum.map_join("–", &(&1 && Decimal.to_string(&1, :normal)))
    |> Kernel.<>(" " <> (option.unit || ""))
    |> String.trim()
  end

  # choices show their price effect: base price per unit, or the surcharge
  defp choice_label(choice, option, product, locale) do
    name = Translated.t(choice.name, locale)

    cond do
      option.role == :base_price and choice.base_price ->
        unit = product.pricing |> pricing_unit() |> Unit.symbol()
        "#{name} – #{Format.money(display_amount(choice.base_price, product), locale)}/#{unit}"

      choice.surcharge_percent && not Decimal.eq?(choice.surcharge_percent, 0) ->
        "#{name} (+#{Format.percent(choice.surcharge_percent)} %)"

      choice.surcharge_amount && not Decimal.eq?(choice.surcharge_amount, 0) ->
        "#{name} (+#{Format.money(display_amount(choice.surcharge_amount, product), locale)} #{Format.per_unit(:piece)})"

      true ->
        name
    end
  end

  defp display_amount(net, product) do
    if Listing.display_gross?() do
      net
      |> Decimal.mult(Decimal.add(100, product.tax_class.rate))
      |> Decimal.div(100)
      |> Decimal.round(2)
    else
      net
    end
  end

  defp pricing_unit(:per_volume), do: :m3
  defp pricing_unit(:per_area), do: :m2
  defp pricing_unit(:per_length), do: :lfm
  defp pricing_unit(_per_unit), do: :piece

  defp line_label(%{type: :base, name: name}, quote, locale) do
    gettext("%{name}: %{measure} %{unit} × %{price}",
      name: Translated.t(name, locale),
      measure: Format.quantity(quote.billed_measure, quote.measure_unit, locale),
      unit: Unit.symbol(quote.measure_unit),
      price: Format.money(quote.base_price, locale)
    )
  end

  defp line_label(%{type: :surcharge, name: name}, _quote, locale), do: Translated.t(name, locale)
  defp line_label(%{type: :cutting_fee}, _quote, _locale), do: gettext("Cutting to size")
  defp line_label(%{type: :minimum}, _quote, _locale), do: gettext("Minimum order surcharge")

  attr :variant, :map, required: true
  attr :product, :map, required: true
  attr :locale, :string, required: true

  defp graduated_prices(assigns) do
    tiers =
      assigns.variant.prices
      |> Enum.reject(& &1.promotion)
      |> Enum.map(& &1.min_quantity)
      |> Enum.uniq()
      |> Enum.sort(Decimal)
      |> Enum.map(fn min ->
        {:ok, info} = Catalog.price_for(%{assigns.variant | product: assigns.product}, min)
        {min, info}
      end)

    assigns = assign(assigns, :tiers, tiers)

    ~H"""
    <div :if={length(@tiers) > 1} id="graduated-prices">
      <p class="font-semibold">{gettext("Graduated prices")}</p>
      <table class="table table-sm w-auto">
        <tbody>
          <tr :for={{min, info} <- @tiers}>
            <td>
              {gettext("from %{quantity} %{unit}",
                quantity: Format.quantity(min, @variant.unit, @locale),
                unit: Unit.symbol(@variant.unit)
              )}
            </td>
            <td class="text-right">{Format.money(Listing.display_price(info), @locale)}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :relations, :list, required: true
  attr :locale, :string, required: true

  defp related(assigns) do
    ~H"""
    <section id={@id}>
      <h2 class="mb-3 text-xl font-bold">{@title}</h2>
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div :for={relation <- @relations} class="flex flex-col gap-1">
          <.product_card
            product={relation.related_product}
            price={from_price(relation.related_product)}
            locale={@locale}
          />
          <p :if={relation.reason} class="text-sm text-base-content/70">
            {Translated.t(relation.reason, @locale)}
          </p>
        </div>
      </div>
    </section>
    """
  end
end
