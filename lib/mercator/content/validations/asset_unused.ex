defmodule Mercator.Content.Validations.AssetUnused do
  @moduledoc """
  An asset can only be deleted when no page uses it, neither in the working
  copy nor in the published version.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    if used?(changeset.data.id) do
      {:error, field: :id, message: "is used on a page"}
    else
      :ok
    end
  end

  @doc "Whether a page block refers to the asset."
  def used?(id) do
    %{rows: [[used?]]} =
      Mercator.Repo.query!(
        "SELECT EXISTS (SELECT 1 FROM pages WHERE blocks::text LIKE $1 OR published::text LIKE $1)",
        ["%#{id}%"]
      )

    used?
  end
end
