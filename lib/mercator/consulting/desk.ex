defmodule Mercator.Consulting.Desk do
  @moduledoc """
  Conversations from the sales desk (guided selling, step 2): lists, taking
  a conversation, writing and closing, as the consultant (`actor`). The
  policies of `Mercator.Consulting.Conversation` allow sales staff and
  administrators. Changes are broadcast like in
  `Mercator.Consulting.Conversations`.
  """
  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query

  alias Mercator.Consulting.{Conversation, Conversations}

  @loads [:customer, :consultant, :product]

  @doc "Waiting conversations, the longest waiting first."
  def waiting(actor) do
    Conversation
    |> Ash.Query.filter(state == :waiting)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.load(@loads)
    |> Ash.read!(actor: actor)
  end

  @doc "Active conversations, newest activity first."
  def active(actor) do
    Conversation
    |> Ash.Query.filter(state == :active)
    |> Ash.Query.sort(last_message_at: :desc_nils_last)
    |> Ash.Query.load(@loads)
    |> Ash.read!(actor: actor)
  end

  @doc "A conversation with its messages, for the desk."
  def get(id, actor) do
    Conversation
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(@loads ++ [messages: [:sender]])
    |> Ash.read_one(actor: actor)
  end

  @doc "The consultant takes (or takes over) a conversation; the customer is told who."
  def take(conversation, actor) do
    with {:ok, conversation} <- Ash.update(conversation, %{}, action: :take, actor: actor) do
      Conversations.create_message(conversation, %{
        sender_kind: :system,
        body: gettext("%{name} is now advising you.", name: display_name(actor))
      })

      conversation = Ash.load!(conversation, @loads, authorize?: false)
      Conversations.broadcast("conversation:#{conversation.id}", {:conversation, conversation})
      Conversations.broadcast("desk", {:conversation, conversation})
      {:ok, conversation}
    end
  end

  @doc "The consultant writes in a conversation."
  def post(conversation, actor, body) do
    Conversations.create_message(conversation, %{
      sender_kind: :consultant,
      sender_id: actor.id,
      body: body
    })
  end

  @doc "The consultant closes a conversation."
  def close(conversation, actor) do
    with {:ok, conversation} <- Ash.update(conversation, %{}, action: :close, actor: actor) do
      Conversations.create_message(conversation, %{
        sender_kind: :system,
        body: gettext("The conversation has ended. Thank you!")
      })

      Conversations.broadcast("conversation:#{conversation.id}", {:conversation, conversation})
      Conversations.broadcast("desk", {:conversation, conversation})
      {:ok, conversation}
    end
  end

  @doc "How staff and customers are named in the desk and the chat."
  def display_name(%{name: name}) when is_binary(name) and name != "", do: name
  def display_name(%{email: email}) when not is_nil(email), do: to_string(email)
  def display_name(_user), do: gettext("Visitor")
end
