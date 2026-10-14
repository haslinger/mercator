defmodule Mercator.Content.Changes.RestoreVersion do
  @moduledoc """
  Copies a published version of the page from its history (#84) into the
  working copy; it goes live with the next publish.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Mercator.Content.Page

  @impl true
  def change(changeset, _opts, _context) do
    version_id = Ash.Changeset.get_argument(changeset, :version_id)
    page_id = changeset.data.id

    Page.Version
    |> Ash.Query.filter(id == ^version_id and version_source_id == ^page_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{changes: %{"published" => published}}} when is_map(published) ->
        changeset
        |> Ash.Changeset.change_attributes(%{
          title: published["title"],
          seo_description: published["seo_description"],
          blocks: published["blocks"] || []
        })
        |> Ash.Changeset.force_change_attribute(:changes_pending, true)

      _ ->
        Ash.Changeset.add_error(changeset, field: :version_id, message: "version not found")
    end
  end
end
