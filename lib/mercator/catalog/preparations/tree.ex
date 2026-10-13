defmodule Mercator.Catalog.Preparations.Tree do
  @moduledoc """
  Filters categories relative to the category given in the `category_id`
  argument, using the `ltree` path (decision #49):

    * `relation: :ancestors` – all ancestors, root first
    * `relation: :subtree` – the category and all its descendants
  """
  use Ash.Resource.Preparation

  require Ash.Query
  require Ash.Sort

  alias Mercator.Catalog.Category

  @impl true
  def prepare(query, opts, _context) do
    category_id = Ash.Query.get_argument(query, :category_id)

    case Ash.get(Category, category_id, authorize?: false) do
      {:ok, category} ->
        path = Enum.join(category.path, ".")
        filter(query, opts[:relation], path, category.id)

      {:error, _} ->
        Ash.Query.filter(query, false)
    end
  end

  defp filter(query, :ancestors, path, id) do
    query
    |> Ash.Query.filter(fragment("? @> ?::ltree", path, ^path) and id != ^id)
    |> Ash.Query.sort(Ash.Sort.expr_sort(fragment("nlevel(?)", path), :integer))
  end

  defp filter(query, :subtree, path, _id) do
    Ash.Query.filter(query, fragment("? <@ ?::ltree", path, ^path))
  end
end
