defmodule Mercator.Sales.Changes.SetFinalShipping do
  @moduledoc """
  On confirmation of an order with estimated freight costs (#65), staff enter
  the final shipping costs (gross); totals and VAT lines are recalculated from
  the order items with `Mercator.Sales.OrderTotals`.
  """
  use Ash.Resource.Change

  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Sales.OrderTotals

  @impl true
  def change(changeset, _opts, _context) do
    shipping_gross = Ash.Changeset.get_argument(changeset, :shipping_gross)

    cond do
      not changeset.data.shipping_estimate ->
        changeset

      is_nil(shipping_gross) ->
        Ash.Changeset.add_error(changeset,
          field: :shipping_gross,
          message: gettext("Please enter the final shipping costs.")
        )

      true ->
        Ash.Changeset.before_action(changeset, &apply_totals(&1, shipping_gross))
    end
  end

  defp apply_totals(changeset, shipping_gross) do
    lines =
      changeset.data
      |> Ash.load!(:items, authorize?: false)
      |> Map.fetch!(:items)
      |> Enum.map(
        &%{available?: true, vat_rate: &1.vat_rate, net: &1.net, vat: &1.vat, gross: &1.gross}
      )

    totals = OrderTotals.calculate(%{lines: lines}, shipping_gross)

    Ash.Changeset.force_change_attributes(changeset,
      shipping_gross: totals.shipping_gross,
      shipping_estimate: false,
      net: totals.net,
      vat: totals.vat,
      gross: totals.gross,
      vat_lines: OrderTotals.snapshot_vat_lines(totals.vat_lines)
    )
  end
end
