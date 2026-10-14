defmodule Mercator.Consulting.Validations.OfferValid do
  @moduledoc "An offer can only be accepted until its validity date."
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def validate(changeset, _opts, _context) do
    if Date.before?(changeset.data.valid_until, Mercator.Clock.today()),
      do: {:error, field: :valid_until, message: gettext("This offer is no longer valid.")},
      else: :ok
  end
end
