defmodule Mercator.Consulting.Workers.SendCallbackRequest do
  @moduledoc """
  Emails a callback request (#95, #97) to the shop address, so it is seen
  even when nobody is at the sales desk.
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  import Swoosh.Email

  alias Mercator.Consulting.{Conversation, Desk}
  alias Mercator.Content.Workers.SendSubmission

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => id}}) do
    conversation =
      Ash.get!(Conversation, id, load: [:customer, messages: [:sender]], authorize?: false)

    with {:ok, _} <- conversation |> email() |> Mercator.Mailer.deliver(), do: :ok
  end

  @doc "The email to the shop."
  def email(conversation) do
    how = if conversation.callback_kind == :email, do: "E-Mail", else: "Telefon"

    questions =
      conversation.messages
      |> Enum.filter(&(&1.sender_kind == :customer))
      |> Enum.map_join("\n", &("> " <> &1.body))

    text = """
    Rückruf gewünscht per #{how}: #{conversation.callback_contact}
    Kunde: #{Desk.display_name(conversation.customer)}
    Thema: #{conversation.subject || "–"} (#{conversation.page || "–"})

    #{questions}

    Das Gespräch wartet am Beratungsplatz: #{MercatorWeb.Endpoint.url()}/admin/desk/#{conversation.id}
    """

    new()
    |> from(Mercator.Mailer.default_from())
    |> to(SendSubmission.recipient())
    |> subject("Rückruf gewünscht: #{conversation.callback_contact}")
    |> text_body(text)
  end
end
