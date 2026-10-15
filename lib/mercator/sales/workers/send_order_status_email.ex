defmodule Mercator.Sales.Workers.SendOrderStatusEmail do
  @moduledoc "Sends the email about a state change of an order (#74), see `OrderEmail.status_change/3`."
  use Oban.Worker, queue: :default, max_attempts: 5

  alias Mercator.Sales.{OrderEmail, OrderEvent}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => event_id}}) do
    event = Ash.get!(OrderEvent, event_id, load: [order: :online_payments], authorize?: false)
    note = if event.to_state == :cancelled, do: event.note

    with {:ok, _} <-
           event.order
           |> OrderEmail.status_change(event.to_state, note)
           |> Mercator.Mailer.deliver(),
         do: :ok
  end
end
