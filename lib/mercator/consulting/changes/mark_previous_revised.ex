defmodule Mercator.Consulting.Changes.MarkPreviousRevised do
  @moduledoc """
  When a revision is created, the offer it replaces becomes `revised` (in
  the same transaction). Only sent or expired offers can be revised.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, offer ->
      previous = Ash.get!(Mercator.Consulting.Offer, offer.previous_offer_id, authorize?: false)

      case Ash.update(previous, %{},
             action: :mark_revised,
             authorize?: false,
             return_notifications?: true
           ) do
        {:ok, _previous, notifications} -> {:ok, offer, notifications}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
