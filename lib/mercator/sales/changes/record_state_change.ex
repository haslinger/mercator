defmodule Mercator.Sales.Changes.RecordStateChange do
  @moduledoc """
  Writes a `Mercator.Sales.OrderEvent` for a state transition, with the
  action's `note` argument and the acting staff member, and emails the
  customer about confirmation, shipping and cancellation (#74) unless the
  `notify` argument is false. Pickup orders get no shipping email: for them
  "shipped" means picked up.
  """
  use Ash.Resource.Change

  alias Mercator.Sales.OrderEvent
  alias Mercator.Sales.Workers.SendOrderStatusEmail

  @impl true
  def change(changeset, _opts, context) do
    from = changeset.data.state
    note = Ash.Changeset.get_argument(changeset, :note)
    notify? = Ash.Changeset.get_argument(changeset, :notify) != false
    user_id = context.actor && context.actor.id

    Ash.Changeset.after_action(changeset, fn _changeset, order ->
      notify? = notify? and email?(order)

      event =
        OrderEvent
        |> Ash.Changeset.for_create(:create, %{
          order_id: order.id,
          from_state: from,
          to_state: order.state,
          note: note,
          customer_notified: notify?,
          user_id: user_id
        })
        |> Ash.create!(authorize?: false)

      if notify?, do: %{event_id: event.id} |> SendOrderStatusEmail.new() |> Oban.insert!()

      {:ok, order}
    end)
  end

  defp email?(%{state: :shipped, shipping_method: :pickup}), do: false
  defp email?(%{state: state}), do: state in [:confirmed, :shipped, :cancelled]
end
