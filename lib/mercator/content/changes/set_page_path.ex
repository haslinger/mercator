defmodule Mercator.Content.Changes.SetPagePath do
  @moduledoc """
  Maintains a page's `path`: the slugs of its ancestors and its own, e.g.
  `ueber-uns/team` (shown at `/pages/ueber-uns/team`, #80).

  When the path of an existing page changes (new slug or new parent), the
  paths of its descendants follow, and the old paths are kept as redirects
  (`Mercator.Content.PageRedirect`). Moving a page below itself or one of
  its descendants is rejected.
  """
  use Ash.Resource.Change

  alias Mercator.Content.Page

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &set_path/1)
  end

  defp set_path(changeset) do
    slug = Ash.Changeset.get_attribute(changeset, :slug)

    case parent_path(Ash.Changeset.get_attribute(changeset, :parent_id)) do
      {:ok, parent_path} -> apply_path(changeset, join(parent_path, slug))
      {:error, message} -> Ash.Changeset.add_error(changeset, field: :parent_id, message: message)
    end
  end

  defp join(nil, slug), do: slug
  defp join(parent_path, slug), do: parent_path <> "/" <> slug

  defp parent_path(nil), do: {:ok, nil}

  defp parent_path(parent_id) do
    case Ash.get(Page, parent_id, authorize?: false) do
      {:ok, parent} -> {:ok, parent.path}
      {:error, _} -> {:error, "parent page does not exist"}
    end
  end

  defp apply_path(%{action_type: :update, data: %{path: old_path}} = changeset, new_path)
       when old_path != new_path do
    if String.starts_with?(new_path, old_path <> "/") do
      Ash.Changeset.add_error(changeset,
        field: :parent_id,
        message: "cannot move a page below itself"
      )
    else
      changeset
      |> Ash.Changeset.force_change_attribute(:path, new_path)
      |> Ash.Changeset.after_action(fn _changeset, page ->
        # the old paths of the page and its descendants keep working (redirects)
        %{rows: moved} =
          Mercator.Repo.query!(
            "UPDATE pages SET path = $2 || substr(path, length($1) + 1) WHERE path LIKE $3 RETURNING id",
            [old_path, new_path, escape_like(old_path) <> "/%"]
          )

        Mercator.Repo.query!(
          """
          INSERT INTO page_redirects (id, old_path, page_id, inserted_at)
          SELECT gen_random_uuid(), $1 || substr(path, length($2) + 1), id, now() AT TIME ZONE 'utc'
          FROM pages WHERE id = ANY($3)
          ON CONFLICT (old_path) DO UPDATE SET page_id = EXCLUDED.page_id
          """,
          [old_path, new_path, [Ecto.UUID.dump!(page.id) | Enum.map(moved, &hd/1)]]
        )

        # a path that is in use again belongs to its page, not to a redirect
        Mercator.Repo.query!(
          "DELETE FROM page_redirects WHERE old_path IN (SELECT path FROM pages)",
          []
        )

        {:ok, page}
      end)
    end
  end

  defp apply_path(changeset, new_path),
    do: Ash.Changeset.force_change_attribute(changeset, :path, new_path)

  defp escape_like(text), do: String.replace(text, ~r/[\\%_]/, "\\\\\\0")
end
