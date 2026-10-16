defmodule Mercator.Consulting.Workers.SendPhoneNotification do
  @moduledoc """
  Sends a phone notification (Web Push, `Mercator.Consulting.PhoneNotifications`)
  to every device of its recipients, in each recipient's language. Events:

    * `"new_conversation"` – to all staff with notifications on, while the
      conversation is still waiting
    * `"message"` – a customer's message, to the conversation's consultant
    * `"test"` – to one device, from the switch at the desk

  Devices the push service reports gone are deleted; other failures are
  logged and not retried (the message would be stale by then).
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query
  require Logger

  alias Mercator.Accounts.PushSubscription
  alias Mercator.Consulting.{Conversation, Desk, Message}
  alias Mercator.WebPush

  @desk_roles [:sales, :sales_manager, :administrator]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => "new_conversation", "conversation_id" => id}}) do
    case Ash.get(Conversation, id, load: [:customer, :messages], authorize?: false) do
      {:ok, %{state: :waiting} = conversation} ->
        subscriptions()
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&Enum.any?(&1.user.roles, fn role -> role in @desk_roles end))
        |> deliver(conversation.id, fn ->
          %{
            title: gettext("New conversation"),
            body: excerpt(Desk.display_name(conversation.customer), first(conversation.messages))
          }
        end)

      _taken_closed_or_gone ->
        :ok
    end
  end

  def perform(%Oban.Job{args: %{"event" => "message", "message_id" => id}}) do
    with {:ok, message} <- Ash.get(Message, id, authorize?: false),
         {:ok, %{consultant_id: consultant_id} = conversation} when not is_nil(consultant_id) <-
           Ash.get(Conversation, message.conversation_id, load: [:customer], authorize?: false) do
      subscriptions()
      |> Ash.Query.filter(user_id == ^consultant_id)
      |> deliver(conversation.id, fn ->
        %{
          title: gettext("Message from %{name}", name: Desk.display_name(conversation.customer)),
          body: excerpt(nil, message)
        }
      end)
    else
      _gone_or_not_taken -> :ok
    end
  end

  def perform(%Oban.Job{args: %{"event" => "test", "user_id" => user_id, "endpoint" => endpoint}}) do
    subscriptions()
    |> Ash.Query.filter(user_id == ^user_id and endpoint == ^endpoint)
    |> deliver(nil, fn ->
      %{
        title: gettext("Notifications are on"),
        body: gettext("This device will be notified about new conversations and messages.")
      }
    end)
  end

  defp subscriptions, do: Ash.Query.load(PushSubscription, :user)

  defp deliver(%Ash.Query{} = query, conversation_id, content),
    do: query |> Ash.read!(authorize?: false) |> deliver(conversation_id, content)

  defp deliver(subscriptions, conversation_id, content) do
    for subscription <- subscriptions do
      payload =
        Gettext.with_locale(MercatorWeb.Gettext, to_string(subscription.user.locale), content)
        |> Map.merge(target(conversation_id))

      case WebPush.deliver(subscription, payload, topic: topic(conversation_id)) do
        :ok ->
          :ok

        {:error, :gone} ->
          Ash.destroy!(subscription, authorize?: false)

        {:error, reason} ->
          Logger.warning(
            "Web Push to #{URI.parse(subscription.endpoint).host} failed: #{inspect(reason)}"
          )
      end
    end

    :ok
  end

  # one notification per conversation: a newer one replaces it
  defp target(nil), do: %{url: "/admin/desk", tag: "test"}
  defp target(id), do: %{url: "/admin/desk/#{id}", tag: "conversation-#{id}"}

  # the push service keeps only the newest undelivered message per topic
  defp topic(nil), do: nil
  defp topic(id), do: String.replace(id, "-", "")

  defp first([message | _]), do: message
  defp first([]), do: nil

  defp excerpt(name, message) do
    text =
      case message do
        %{body: body} when is_binary(body) and body != "" -> String.slice(body, 0, 140)
        _attachment -> gettext("(attachment)")
      end

    if name, do: "#{name}: #{text}", else: text
  end
end
