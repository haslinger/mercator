defmodule Mercator.Consulting.Workers.SendOfferEmail do
  @moduledoc """
  Emails about an offer: `"sent"` to the customer, with the offer as PDF
  (#17), `"approval"` to the sales managers (#98).
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  require Ash.Query

  alias Mercator.Accounts.User
  alias Mercator.Consulting.{ConsultingEmail, Offer}
  alias MercatorWeb.Documents

  @doc "Schedules an email about an offer: `:sent` or `:approval`."
  def enqueue(offer_id, kind) when kind in [:sent, :approval],
    do: %{offer_id: offer_id, kind: kind} |> new() |> Oban.insert!()

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"offer_id" => id, "kind" => kind}}) do
    offer = Ash.get!(Offer, id, load: [:customer, :consultant, :items], authorize?: false)

    case email(offer, kind) do
      nil -> :ok
      email -> with {:ok, _} <- Mercator.Mailer.deliver(email), do: :ok
    end
  end

  defp email(%{state: :sent} = offer, "sent") do
    offer
    |> ConsultingEmail.offer_sent()
    |> Documents.attach_pdf(Documents.offer_pdf(offer), Documents.offer_filename(offer))
  end

  defp email(%{state: :pending_approval} = offer, "approval") do
    case sales_managers() do
      [] -> nil
      recipients -> ConsultingEmail.approval_request(offer, recipients)
    end
  end

  # the offer changed meanwhile (e.g. withdrawn)
  defp email(_offer, _kind), do: nil

  defp sales_managers do
    User
    |> Ash.Query.filter(fragment("'sales_manager' = ANY(?)", roles))
    |> Ash.read!(authorize?: false)
    |> Enum.map(&to_string(&1.email))
  end
end
