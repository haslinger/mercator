defmodule Mercator.Catalog.Preparations.Search do
  @moduledoc """
  Product search (decision #56). A product matches when any of these holds:

    * the German or English full-text document matches all words as
      prefixes (German stemming also folds umlauts: "Larche" finds "Lärche")
    * the German or English title contains all words as substrings, which
      catches parts of German compounds ("holz" in "Brennholz")
    * the article number starts with the query ("BH-TD")

  Results are ordered by full-text rank (title matches weigh more).
  """
  use Ash.Resource.Preparation

  require Ash.Query
  require Ash.Sort

  @impl true
  def prepare(query, _opts, _context) do
    words = query |> Ash.Query.get_argument(:query) |> words()

    if words == [] do
      Ash.Query.filter(query, false)
    else
      tsquery = Enum.map_join(words, " & ", &(&1 <> ":*"))
      patterns = Enum.map(words, &("%" <> &1 <> "%"))
      number_prefix = String.upcase(String.trim(Ash.Query.get_argument(query, :query))) <> "%"

      query
      |> Ash.Query.filter(
        fragment(
          "mercator_product_document('german', 'de', ?, ?, ?) @@ to_tsquery('german', ?)",
          title,
          subtitle,
          description,
          ^tsquery
        ) or
          fragment(
            "mercator_product_document('english', 'en', ?, ?, ?) @@ to_tsquery('english', ?)",
            title,
            subtitle,
            description,
            ^tsquery
          ) or
          fragment(
            "coalesce(?->>'de', '') || ' ' || coalesce(?->>'en', '') ILIKE ALL(?)",
            title,
            title,
            ^patterns
          ) or
          fragment("? ILIKE ?", number, ^number_prefix)
      )
      |> Ash.Query.sort(
        {Ash.Sort.expr_sort(
           fragment(
             "ts_rank(mercator_product_document('german', 'de', ?, ?, ?), to_tsquery('german', ?)) + ts_rank(mercator_product_document('english', 'en', ?, ?, ?), to_tsquery('english', ?))",
             title,
             subtitle,
             description,
             ^tsquery,
             title,
             subtitle,
             description,
             ^tsquery
           ),
           :float
         ), :desc}
      )
    end
  end

  @doc false
  # Letters and digits only (keeps umlauts), so the tsquery is always valid.
  def words(nil), do: []

  def words(query) do
    query
    |> String.downcase()
    |> String.split(~r/[^\p{L}\p{N}]+/u, trim: true)
    |> Enum.filter(&(String.length(&1) >= 2))
    |> Enum.take(8)
  end
end
