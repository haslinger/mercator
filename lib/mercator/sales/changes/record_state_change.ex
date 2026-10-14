defmodule Mercator.Sales.Changes.RecordStateChange do
  @moduledoc """
  Writes a `Mercator.Sales.OrderEvent` for a state transition, with the
  action's `note` argument and the acting staff member.
  """
  use Ash.Resource.Change

  alias Mercator.Sales.OrderEvent

  @impl true
  def change(changeset, _opts, context) do
    from = changeset.data.state
    note = Ash.Changeset.get_argument(changeset, :note)
    user_id = context.actor && context.actor.id

    Ash.Changeset.after_action(changeset, fn _changeset, order ->
      OrderEvent
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        from_state: from,
        to_state: order.state,
        note: note,
        user_id: user_id
      })
      |> Ash.create!(authorize?: false)

      {:ok, order}
    end)
  end
end
