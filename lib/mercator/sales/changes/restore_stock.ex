defmodule Mercator.Sales.Changes.RestoreStock do
  @moduledoc """
  Puts the ordered quantities back into stock when an order is cancelled
  (checkout-design.md, section 4). Like the reduction at checkout, only
  variants with a tracked stock are touched (#54).
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Mercator.Catalog
  alias Mercator.Catalog.Variant

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, order ->
      notifications =
        order
        |> Ash.load!(:items, authorize?: false)
        |> Map.fetch!(:items)
        |> Enum.reject(&is_nil(&1.variant_id))
        |> Enum.group_by(& &1.variant_id, & &1.quantity)
        |> Enum.flat_map(fn {variant_id, quantities} ->
          restore(variant_id, Enum.reduce(quantities, &Decimal.add/2))
        end)

      {:ok, order, notifications}
    end)
  end

  defp restore(variant_id, quantity) do
    variant =
      Variant
      |> Ash.Query.filter(id == ^variant_id)
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read_one!(authorize?: false)

    if variant && variant.stock do
      {_variant, notifications} =
        Catalog.update_variant!(variant, %{stock: Decimal.add(variant.stock, quantity)},
          authorize?: false,
          return_notifications?: true
        )

      notifications
    else
      []
    end
  end
end
