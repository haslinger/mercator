defmodule Mercator.Consulting.Workers.SendReplyNotice do
  @moduledoc """
  A consultant answered while the customer was not in the shop (#97): one
  email a minute later with the answers since the customer's last
  message, unless the customer has come back meanwhile. At most one email
  per conversation every 10 minutes. Visitors get it only when they left
  an email address for a callback (#95).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: 600, keys: [:conversation_id], states: [:available, :scheduled]]

  alias Mercator.Consulting.{ConsultingEmail, Conversation}

  @doc "Schedules the email for a conversation."
  def enqueue(conversation_id),
    do: %{conversation_id: conversation_id} |> new(schedule_in: 60) |> Oban.insert!()

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => id}}) do
    conversation =
      Ash.get!(Conversation, id,
        load: [:customer, messages: [:product]],
        authorize?: false
      )

    with false <- MercatorWeb.Presence.customer_online?(id),
         recipient when is_binary(recipient) <- recipient(conversation),
         [_ | _] = messages <- unanswered(conversation.messages),
         {:ok, _} <-
           recipient
           |> ConsultingEmail.reply_notice(locale(conversation), messages)
           |> Mercator.Mailer.deliver() do
      :ok
    else
      {:error, reason} -> {:error, reason}
      _nothing_to_send -> :ok
    end
  end

  defp recipient(%{customer: %{email: email}}), do: to_string(email)
  defp recipient(%{callback_kind: :email, callback_contact: contact}), do: contact
  defp recipient(_conversation), do: nil

  defp locale(%{customer: %{locale: locale}}) when not is_nil(locale), do: to_string(locale)
  defp locale(_conversation), do: "de"

  # the consultant's messages after the customer's last one
  defp unanswered(messages) do
    messages
    |> Enum.reverse()
    |> Enum.take_while(&(&1.sender_kind != :customer))
    |> Enum.filter(&(&1.sender_kind == :consultant))
    |> Enum.reverse()
  end
end
