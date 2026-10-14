defmodule Mercator.Content.Changes.Publish do
  @moduledoc """
  Publishes the working copy (#90): copies title, SEO description and
  blocks to `published`. A draft or archived page becomes `published`; a
  hidden page stays hidden. AshPaperTrail records the result as a version.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    page = changeset.data

    published = %{
      title: page.title,
      seo_description: page.seo_description,
      blocks: page.blocks
    }

    target = if page.state in [:published, :hidden], do: page.state, else: :published

    changeset
    |> Ash.Changeset.force_change_attributes(
      published: published,
      published_at: DateTime.utc_now(),
      changes_pending: false
    )
    |> AshStateMachine.transition_state(target)
  end
end
