defmodule Mercator.Catalog.Slug do
  @moduledoc """
  URL slugs from German names: lower case, umlauts transliterated
  (ä → ae, ß → ss), everything else non-alphanumeric becomes a dash.

      iex> Mercator.Catalog.Slug.slugify("Kanthölzer & Balken")
      "kanthoelzer-balken"
  """

  @replacements [{"ä", "ae"}, {"ö", "oe"}, {"ü", "ue"}, {"ß", "ss"}]

  def slugify(nil), do: nil

  def slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> then(fn text ->
      Enum.reduce(@replacements, text, fn {from, to}, acc -> String.replace(acc, from, to) end)
    end)
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end
end
