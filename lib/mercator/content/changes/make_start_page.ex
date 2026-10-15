defmodule Mercator.Content.Changes.MakeStartPage do
  @moduledoc """
  Makes a published page the start page: it gets the key `home`, which the
  previous start page loses in the same transaction (keys are unique).
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Mercator.Content.Page

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attribute(:key, "home")
    |> Ash.Changeset.before_action(fn changeset ->
      Page
      |> Ash.Query.filter(key == "home" and id != ^changeset.data.id)
      |> Ash.bulk_update!(:clear_key, %{}, authorize?: false, strategy: [:atomic, :stream])

      changeset
    end)
  end
end
