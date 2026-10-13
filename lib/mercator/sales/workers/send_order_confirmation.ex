defmodule Mercator.Sales.Workers.SendOrderConfirmation do
  @moduledoc "Sends the confirmation email of a newly placed order."
  use Oban.Worker, queue: :default, max_attempts: 5

  alias Mercator.Sales.{Order, OrderEmail}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id}}) do
    order = Ash.get!(Order, order_id, load: [:items], authorize?: false)

    with {:ok, _} <- order |> OrderEmail.confirmation() |> Mercator.Mailer.deliver(), do: :ok
  end
end
