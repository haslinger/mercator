defmodule Mercator.Catalog.Changes.SetCategoryPath do
  @moduledoc """
  Maintains the materialised `ltree` path of a category (decision #49):
  the ids of all ancestors and the category itself, e.g. `root_id.child_id`.

  On create it derives the path from the parent. On `move` it also rejects
  cycles (moving a category below itself or one of its descendants) and
  rewrites the paths of all descendants.
  """
  use Ash.Resource.Change

  alias Mercator.Catalog.Category

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &set_path/1)
  end

  defp set_path(changeset) do
    changeset = ensure_id(changeset)
    id = Ash.Changeset.get_attribute(changeset, :id)

    case parent_path(Ash.Changeset.get_attribute(changeset, :parent_id)) do
      {:ok, parent_path} -> apply_path(changeset, parent_path, label(id))
      {:error, message} -> Ash.Changeset.add_error(changeset, field: :parent_id, message: message)
    end
  end

  defp apply_path(%{action_type: :update} = changeset, parent_path, label)
       when is_list(parent_path) and parent_path != [] do
    if label in parent_path do
      Ash.Changeset.add_error(changeset,
        field: :parent_id,
        message: "cannot move a category below itself"
      )
    else
      do_apply_path(changeset, parent_path ++ [label])
    end
  end

  defp apply_path(changeset, parent_path, label),
    do: do_apply_path(changeset, parent_path ++ [label])

  defp do_apply_path(changeset, new_path) do
    changeset
    |> Ash.Changeset.force_change_attribute(:path, new_path)
    |> maybe_move_descendants(new_path)
  end

  @doc "The ltree label of a category id."
  def label(id), do: id

  defp ensure_id(changeset) do
    case Ash.Changeset.get_attribute(changeset, :id) do
      nil -> Ash.Changeset.force_change_attribute(changeset, :id, Ash.UUID.generate())
      _id -> changeset
    end
  end

  defp parent_path(nil), do: {:ok, []}

  defp parent_path(parent_id) do
    case Ash.get(Category, parent_id, authorize?: false) do
      {:ok, parent} -> {:ok, parent.path}
      {:error, _} -> {:error, "parent category does not exist"}
    end
  end

  # When an existing category moves, its descendants keep their relative
  # position: their path prefix changes from the old to the new path.
  defp maybe_move_descendants(
         %{action_type: :update, data: %{path: old_path}} = changeset,
         new_path
       )
       when old_path != new_path do
    Ash.Changeset.after_action(changeset, fn _changeset, category ->
      Mercator.Repo.query!(
        """
        UPDATE categories
        SET path = $2::ltree || subpath(path, nlevel($1::ltree))
        WHERE path <@ $1::ltree AND path <> $1::ltree
        """,
        [Enum.join(old_path, "."), Enum.join(new_path, ".")]
      )

      {:ok, category}
    end)
  end

  defp maybe_move_descendants(changeset, _new_path), do: changeset
end
