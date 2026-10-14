defmodule Mercator.Content.Changes.NormalizeTags do
  @moduledoc "Tags of an asset are trimmed, lower case and unique (#85)."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :tags) do
      tags when is_list(tags) ->
        tags =
          tags
          |> Enum.flat_map(&String.split(&1, ","))
          |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()

        Ash.Changeset.force_change_attribute(changeset, :tags, tags)

      _ ->
        changeset
    end
  end
end
