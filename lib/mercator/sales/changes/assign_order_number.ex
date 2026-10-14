defmodule Mercator.Sales.Changes.AssignOrderNumber do
  @moduledoc """
  Assigns the next order number of the current year (#68), e.g.
  `BH-2026-00042`. The counter row in `order_number_counters` is incremented
  inside the order's transaction, so numbers are gap-free: a failed order
  rolls its number back.
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

  @doc "The order number for a year and sequence, with the brand's prefix."
  def format(year, sequence) do
    number = "#{year}-#{String.pad_leading(to_string(sequence), 5, "0")}"

    case Mercator.Brand.get(:order_prefix) do
      nil -> number
      prefix -> "#{prefix}-#{number}"
    end
  end

  defp next(year) do
    %{rows: [[sequence]]} =
      Mercator.Repo.query!(
        """
        INSERT INTO order_number_counters (year, last) VALUES ($1, 1)
        ON CONFLICT (year) DO UPDATE SET last = order_number_counters.last + 1
        RETURNING last
        """,
        [year]
      )

    sequence
  end
end
