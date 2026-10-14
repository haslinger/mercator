defmodule Mercator.Sales.Preparations.SearchOrders do
  @moduledoc """
  Filters of the back office order search (`Order` action `:search`):

    * `:from` / `:to` are local dates of the shop (#73), inclusive
    * `:query` matches order number, email, customer name and company,
      case-insensitively; `%` and `_` are taken literally
  """
  use Ash.Resource.Preparation

  require Ash.Query

  alias Mercator.Clock

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> from(Ash.Query.get_argument(query, :from))
    |> to(Ash.Query.get_argument(query, :to))
    |> text(String.trim(Ash.Query.get_argument(query, :query) || ""))
  end

  defp from(query, nil), do: query
  defp from(query, date), do: Ash.Query.filter(query, inserted_at >= ^Clock.start_of_day(date))

  defp to(query, nil), do: query

  defp to(query, date),
    do: Ash.Query.filter(query, inserted_at < ^Clock.start_of_day(Date.add(date, 1)))

  defp text(query, ""), do: query

  defp text(query, text) do
    pattern = "%" <> String.replace(text, ~r/[\\%_]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      fragment(
        "concat_ws(' ', ?, ?, ? ->> 'name', ? ->> 'company') ILIKE ?",
        number,
        email,
        billing_address,
        billing_address,
        ^pattern
      )
    )
  end
end
