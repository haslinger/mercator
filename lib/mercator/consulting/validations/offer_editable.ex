defmodule Mercator.Consulting.Validations.OfferEditable do
  @moduledoc """
  Items can only be changed while their offer is a draft. Items created
  together with their offer (a revision) get the offer id later and pass.
  """
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :offer_id) do
      nil -> :ok
      offer_id -> validate_draft(offer_id)
    end
  end

  defp validate_draft(offer_id) do
    state =
      Mercator.Consulting.Offer
      |> Ash.Query.filter(id == ^offer_id)
      |> Ash.Query.select([:state])
      |> Ash.read_one!(authorize?: false)
      |> then(&(&1 && &1.state))

    if state == :draft,
      do: :ok,
      else: {:error, field: :offer_id, message: gettext("Only drafts can be changed.")}
  end
end
