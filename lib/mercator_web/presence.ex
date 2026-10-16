defmodule MercatorWeb.Presence do
  @moduledoc """
  Who is at the sales desk (guided selling, #95): consultants with the desk
  open are tracked on `"desk:presence"` with `%{available: boolean, name: ...,
  conversation_id: ...}` (the conversation they have open).
  Kept in memory across the cluster by Phoenix.Presence, not in the database.
  """
  use Phoenix.Presence, otp_app: :mercator, pubsub_server: Mercator.PubSub

  @topic "desk:presence"

  def topic, do: @topic

  @doc "Number of consultants at the desk who are available."
  def available_count do
    @topic
    |> list()
    |> Enum.count(fn {_id, %{metas: metas}} -> Enum.any?(metas, & &1.available) end)
  end

  @doc "Whether the consultant has this conversation open at the desk (`conversation_id` in the meta)."
  def viewing?(user_id, conversation_id) do
    case get_by_key(@topic, user_id) do
      %{metas: metas} -> Enum.any?(metas, &(&1[:conversation_id] == conversation_id))
      _not_at_desk -> false
    end
  end

  @chat_topic "chat:presence"

  @doc "Topic of customers with an open conversation in their chat widget."
  def chat_topic, do: @chat_topic

  @doc "Tracks the customer's chat widget for a conversation (online status on the desk)."
  def track_customer(pid, conversation_id), do: track(pid, @chat_topic, conversation_id, %{})

  @doc "Whether the customer of a conversation has the shop open."
  def customer_online?(conversation_id), do: get_by_key(@chat_topic, conversation_id) != []
end
