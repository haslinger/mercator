defmodule Mercator.Sales.Workers.SendOrderConfirmation do
  @moduledoc "Sends the confirmation email of a newly placed order, with the PDF (#17)."
  use Oban.Worker, queue: :default, max_attempts: 5

  alias Mercator.Sales.{Order, OrderEmail}
  alias MercatorWeb.Documents

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id}}) do
    order = Ash.get!(Order, order_id, load: [:items], authorize?: false)

    email =
      order
      |> OrderEmail.confirmation()
      |> Documents.attach_pdf(Documents.order_pdf(order), Documents.order_filename(order))

    with {:ok, _} <- Mercator.Mailer.deliver(email), do: :ok
  end
end
