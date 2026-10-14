defmodule MercatorWeb.BlockData do
  @moduledoc """
  Loads what the blocks of a page show besides their own fields: media
  library files, products (with their from price) and categories. The
  result is the `data` map of `MercatorWeb.ContentComponents.block/1`:

      %{assets: %{id => asset}, products: %{block_id => [{product, price}]},
        categories: %{block_id => [category]}}

  Products and categories are read as visitors see them (active only).
  """
  require Ash.Query

  alias Mercator.{Catalog, Content}
  alias Mercator.Catalog.{Category, Listing, Product}
  alias Mercator.Content.Blocks

  def load(blocks) do
    values = Enum.map(blocks, & &1.value)

    %{
      assets: Content.assets_for_blocks(blocks),
      products: for(%Blocks.Products{} = b <- values, into: %{}, do: {b.id, products(b)}),
      categories: for(%Blocks.Categories{} = b <- values, into: %{}, do: {b.id, categories(b)})
    }
  end

  defp products(block) do
    block
    |> product_query()
    |> Ash.Query.load(Listing.loads())
    |> Ash.read!()
    |> order(block)
    |> Enum.take(block.limit || 4)
    |> Enum.map(&{&1, from_price(&1)})
  end

  defp product_query(%{source: :new_arrivals}),
    do: Product |> Ash.Query.filter(new_arrival) |> Ash.Query.sort(inserted_at: :desc)

  defp product_query(%{source: :category, category_id: id}) when not is_nil(id) do
    ids = id |> Catalog.list_category_subtree!() |> Enum.map(& &1.id)

    Product
    |> Ash.Query.filter(exists(categorizations, category_id in ^ids))
    |> Ash.Query.sort(number: :asc)
  end

  defp product_query(%{source: :numbers} = block),
    do: Ash.Query.filter(Product, number in ^numbers(block))

  defp product_query(_bestsellers),
    do: Product |> Ash.Query.filter(bestseller) |> Ash.Query.sort(number: :asc)

  # chosen article numbers keep the order they were entered in
  defp order(products, %{source: :numbers} = block) do
    position = block |> numbers() |> Enum.with_index() |> Map.new()
    Enum.sort_by(products, &Map.get(position, &1.number, 0))
  end

  defp order(products, _block), do: products

  defp numbers(%{numbers: numbers}),
    do: String.split(numbers || "", [",", " ", "\n"], trim: true) |> Enum.map(&String.upcase/1)

  defp from_price(product) do
    case Catalog.from_price(product) do
      {:ok, info} -> info
      _ -> nil
    end
  end

  defp categories(%{category_ids: []}),
    do: [load: :images] |> Catalog.list_root_categories!() |> Enum.filter(&(&1.state == :active))

  defp categories(%{category_ids: ids}) do
    found = Category |> Ash.Query.filter(id in ^ids) |> Ash.Query.load(:images) |> Ash.read!()
    Enum.flat_map(ids, fn id -> Enum.filter(found, &(&1.id == id)) end)
  end
end
