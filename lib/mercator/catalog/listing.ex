defmodule Mercator.Catalog.Listing do
  @moduledoc """
  Filtering, faceting and sorting of the products on a category page.

  Works on loaded products in memory, which is fine for category sizes of a
  few hundred products. Filters (from URL params, all optional):

    * `"min"`, `"max"` – price range (gross or net, see `display_gross?/0`)
    * `"p"` – `%{property_id => [value_key, ...]}` for filterable properties
    * `"new"`, `"bestseller"`, `"sale"` – `"1"` to restrict to flagged products
    * `"sort"` – `"position"` (default), `"price_asc"`, `"price_desc"`, `"name"`, `"newest"`
  """

  alias Mercator.Catalog.Pricing
  alias Mercator.Translated

  @loads [
    :tax_class,
    :images,
    variants: :prices,
    options: :choices,
    product_properties: :property
  ]

  @doc "What to load on products before calling `build/3`."
  def loads, do: @loads

  @doc "Whether prices are shown gross (B2C) or net (B2B), a shop setting (#50)."
  def display_gross?, do: Application.get_env(:mercator, :price_display, :gross) == :gross

  @doc "The displayed unit price of a `PriceInfo`."
  def display_price(info), do: if(display_gross?(), do: info.unit_gross, else: info.unit_net)

  @doc """
  Builds the listing. Returns a map with `:entries` (`{product, price_info}`,
  price_info may be nil), `:facets`, `:count` and `:total`.
  """
  def build(products, params, locale) do
    entries = for product <- products, do: {product, price_info(product)}

    filtered =
      entries
      |> filter_flags(params)
      |> filter_price(params)
      |> filter_properties(params["p"] || %{})

    %{
      entries: sort(filtered, params["sort"], locale),
      facets: facets(entries, locale),
      count: length(filtered),
      total: length(entries)
    }
  end

  defp price_info(product) do
    case Pricing.from_price(product) do
      {:ok, info} -> info
      {:error, _} -> nil
    end
  end

  # --- Filters ---

  defp filter_flags(entries, params) do
    entries
    |> keep_if(params["new"] == "1", fn {p, _} -> p.new_arrival end)
    |> keep_if(params["bestseller"] == "1", fn {p, _} -> p.bestseller end)
    |> keep_if(params["sale"] == "1", fn {_, info} -> info && info.promotion? end)
  end

  defp filter_price(entries, params) do
    min = decimal(params["min"])
    max = decimal(params["max"])

    entries
    |> keep_if(min != nil, fn {_, info} ->
      info && Decimal.compare(display_price(info), min) != :lt
    end)
    |> keep_if(max != nil, fn {_, info} ->
      info && Decimal.compare(display_price(info), max) != :gt
    end)
  end

  defp filter_properties(entries, selected) when is_map(selected) do
    Enum.reduce(selected, entries, fn
      {_property_id, []}, acc ->
        acc

      {property_id, keys}, acc ->
        keys = List.wrap(keys)

        Enum.filter(acc, fn {product, _} ->
          Enum.any?(
            product.product_properties,
            &(&1.property_id == property_id and value_key(&1) in keys)
          )
        end)
    end)
  end

  defp filter_properties(entries, _selected), do: entries

  defp keep_if(entries, false, _fun), do: entries
  defp keep_if(entries, true, fun), do: Enum.filter(entries, fun)

  defp decimal(nil), do: nil
  defp decimal(""), do: nil

  defp decimal(value) do
    case Decimal.parse(String.replace(value, ",", ".")) do
      {decimal, ""} -> decimal
      _ -> nil
    end
  end

  # --- Facets ---

  @doc """
  The filterable properties occurring in the products, each with its values
  (`{key, label, count}`), ordered like the properties.
  """
  def facets(entries, locale) do
    entries
    |> Enum.flat_map(fn {product, _} -> product.product_properties end)
    |> Enum.filter(& &1.property.filterable)
    |> Enum.group_by(& &1.property)
    |> Enum.sort_by(fn {property, _} -> property.position end)
    |> Enum.map(fn {property, values} ->
      %{
        property: property,
        values:
          values
          |> Enum.group_by(&value_key/1)
          |> Enum.map(fn {key, [value | _] = all} ->
            {key, value_label(value, locale), length(all)}
          end)
          |> Enum.sort_by(fn {_key, label, _count} -> label end)
      }
    end)
    |> Enum.filter(&(length(&1.values) > 1))
  end

  @doc "A language-neutral key for a property value, used in filter URLs."
  def value_key(%{property: %{kind: :text}} = value), do: Translated.t(value.text_value, "de")

  def value_key(%{property: %{kind: :number}} = value),
    do: value.number_value |> Decimal.normalize() |> Decimal.to_string(:normal)

  def value_key(%{property: %{kind: :boolean}} = value), do: to_string(value.boolean_value)

  @doc ~s(The displayed value of a product property, e.g. "28 mm" or "Lärche".)
  def value_label(%{property: %{kind: :text}} = value, locale),
    do: Translated.t(value.text_value, locale)

  def value_label(%{property: %{kind: :number, unit: unit}} = value, locale) do
    number = value.number_value |> Decimal.normalize() |> Decimal.to_string(:normal)
    number = if to_string(locale) == "en", do: number, else: String.replace(number, ".", ",")
    if unit, do: "#{number} #{unit}", else: number
  end

  def value_label(%{property: %{kind: :boolean}} = value, locale) do
    case {value.boolean_value, to_string(locale)} do
      {true, "en"} -> "yes"
      {true, _} -> "ja"
      {false, "en"} -> "no"
      {false, _} -> "nein"
    end
  end

  # --- Sorting ---

  defp sort(entries, "price_asc", _locale),
    do: Enum.sort_by(entries, &price_key/1, &compare_prices/2)

  defp sort(entries, "price_desc", _locale),
    do: Enum.sort_by(entries, &price_key/1, &compare_prices(&2, &1))

  defp sort(entries, "name", locale),
    do: Enum.sort_by(entries, fn {p, _} -> Translated.t(p.title, locale) end)

  defp sort(entries, "newest", _locale),
    do: Enum.sort_by(entries, fn {p, _} -> p.inserted_at end, {:desc, DateTime})

  defp sort(entries, _position, _locale), do: entries

  defp price_key({_product, nil}), do: nil
  defp price_key({_product, info}), do: display_price(info)

  # products without price go last
  defp compare_prices(nil, _b), do: false
  defp compare_prices(_a, nil), do: true
  defp compare_prices(a, b), do: Decimal.compare(a, b) != :gt
end
