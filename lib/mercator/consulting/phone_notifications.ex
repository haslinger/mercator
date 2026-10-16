defmodule Mercator.Consulting.PhoneNotifications do
  @moduledoc """
  Phone notifications for the sales desk (#151–#153), sent with Web Push
  (`Mercator.WebPush`) to the devices staff switched them on for at the
  desk (`Mercator.Accounts.PushSubscription`):

    * a customer **starts a conversation**: every staff member with
      notifications on, all at the same time (#153)
    * a customer **writes in a taken conversation**: only its consultant,
      unless they have it open at the desk

  Sending runs in `Mercator.Consulting.Workers.SendPhoneNotification`.
  Delivery is best effort (#151): the desk ringing and the callback form
  stay the safety net.
  """
  require Ash.Query

  alias Mercator.Accounts
  alias Mercator.Accounts.PushSubscription
  alias Mercator.Consulting.Workers.SendPhoneNotification
  alias Mercator.WebPush

  @doc "Whether phone notifications are possible (Web Push keys configured)."
  def enabled?, do: WebPush.enabled?()

  @doc "A customer started a conversation."
  def new_conversation(conversation_id),
    do: enqueue(%{event: "new_conversation", conversation_id: conversation_id})

  @doc "A customer wrote in their conversation."
  def customer_message(%{state: :active, consultant_id: consultant_id} = conversation, message)
      when not is_nil(consultant_id) do
    unless MercatorWeb.Presence.viewing?(consultant_id, conversation.id),
      do: enqueue(%{event: "message", message_id: message.id})

    :ok
  end

  def customer_message(_waiting_or_closed, _message), do: :ok

  @doc "A test notification to one of the user's devices."
  def test(user, endpoint),
    do: enqueue(%{event: "test", user_id: user.id, endpoint: endpoint})

  defp enqueue(args) do
    if enabled?(), do: args |> SendPhoneNotification.new() |> Oban.insert!()
    :ok
  end

  @doc """
  Switches notifications on for this device: `params` as the browser's
  subscription (`"endpoint"`, `"p256dh"`, `"auth"`, `"user_agent"`).
  """
  def subscribe(user, params) do
    params
    |> Map.take(["endpoint", "p256dh", "auth", "user_agent"])
    |> Map.update("user_agent", nil, &(&1 && String.slice(&1, 0, 500)))
    |> Accounts.subscribe_push(actor: user)
  end

  @doc "Switches notifications off for this device."
  def unsubscribe(user, endpoint) do
    PushSubscription
    |> Ash.Query.filter(user_id == ^user.id and endpoint == ^endpoint)
    |> Ash.bulk_destroy!(:destroy, %{}, actor: user, strategy: :stream)

    :ok
  end
end
