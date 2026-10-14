defmodule Mercator.Sales.Validations.GtcNotInForce do
  @moduledoc """
  GTC versions in force are fixed (#92): with `field: :version` the new date
  must be today or later; with `data: true` the stored version must not be
  in force yet (for editing and deleting).
  """
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Clock

  @impl true
  def validate(changeset, opts, _context) do
    today = Clock.today()

    cond do
      opts[:data] && Date.compare(changeset.data.version, today) != :gt ->
        {:error,
         field: :version,
         message: dgettext_noop("errors", "is already in force and cannot be changed")}

      opts[:field] && before_today?(Ash.Changeset.get_attribute(changeset, opts[:field]), today) ->
        {:error, field: opts[:field], message: dgettext_noop("errors", "must be today or later")}

      true ->
        :ok
    end
  end

  defp before_today?(%Date{} = date, today), do: Date.compare(date, today) == :lt
  defp before_today?(_date, _today), do: false
end
