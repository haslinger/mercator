defmodule Mercator.Content.Changes.DiscardChanges do
  @moduledoc "Resets the working copy of a page to its published version (#90)."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case changeset.data.published do
      nil ->
        changeset

      published ->
        Ash.Changeset.force_change_attributes(changeset,
          title: published.title,
          seo_description: published.seo_description,
          blocks: published.blocks,
          changes_pending: false
        )
    end
  end
end
