defmodule Mercator.Consulting.Changes.AssignOfferNumber do
  @moduledoc """
  Assigns the next offer number of the current year, e.g. `BH-A-2026-00012`
  (like order numbers, #68, with an `A` for "Angebot"). Gap-free: the counter
  in `offer_number_counters` is incremented in the offer's transaction.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      year = Mercator.Clock.today().year
      sequence = next(year)

      Ash.Changeset.force_change_attributes(changeset,
        year: year,
        sequence: sequence,
        number: format(year, sequence)
      )
    end)
  end

  @doc "The offer number for a year and sequence, with the brand's prefix."
  def format(year, sequence) do
    number = "A-#{year}-#{String.pad_leading(to_string(sequence), 5, "0")}"

    case Mercator.Brand.get(:order_prefix) do
      nil -> number
      prefix -> "#{prefix}-#{number}"
    end
  end

  defp next(year) do
    %{rows: [[sequence]]} =
      Mercator.Repo.query!(
        """
        INSERT INTO offer_number_counters (year, last) VALUES ($1, 1)
        ON CONFLICT (year) DO UPDATE SET last = offer_number_counters.last + 1
        RETURNING last
        """,
        [year]
      )

    sequence
  end
end
