defmodule Mercator.Consulting.Conversations do
  @moduledoc """
  Conversations from the customer's side. Every function takes the owner,
  like `Mercator.Sales.Baskets`:

    * `{:session, token}` – a visitor (#94)
    * `{:user, user}` – a signed-in customer

  Operations run without an actor but are scoped to the owner's
  conversations. Changes are broadcast with Phoenix PubSub:

    * `"conversation:<id>"` – `{:message, message}`, `{:conversation, conversation}`
    * `"desk"` – `{:conversation, conversation}` for the sales desk
  """
  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query

  alias Mercator.Catalog.Listing
  alias Mercator.Consulting.{Call, Calls, Conversation, Message, PhoneNotifications}
  alias Mercator.Consulting.Workers.{SendCallbackRequest, SendNewConversationNotice}

  @pubsub Mercator.PubSub

  @doc "The owner's open conversation (waiting or active) with its messages, or nil."
  def current(owner) do
    Conversation
    |> filter_owner(owner)
    |> Ash.Query.filter(state in [:waiting, :active])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.Query.load([:consultant, messages: message_loads()])
    |> Ash.read_one!(authorize?: false)
  end

  @doc """
  Starts a conversation with the customer's first message. `context` may
  hold `:subject`, `:page` and `:product_id`.
  """
  def start(owner, body, context \\ %{}),
    do: open(owner, context, &post(owner, &1.id, body))

  @doc """
  Starts a conversation without writing (#155): the customer would rather
  talk. The consultant who takes it sees the request and calls; the chat is
  there for links, products and offers. When nobody is at the desk, the
  widget offers the callback right away (#95).
  """
  def start_call(owner, context \\ %{}),
    do: open(owner, context, &mark_call_requested/1)

  defp open(owner, context, first) do
    attrs =
      context
      |> Map.take([:subject, :page, :product_id])
      |> Map.put(:current_page, context[:page])
      |> Map.merge(owner_attrs(owner))

    with {:ok, conversation} <- Ash.create(Conversation, attrs, action: :start, authorize?: false),
         {:ok, _first} <- first.(conversation) do
      conversation = current(owner)
      broadcast("desk", {:conversation, conversation})

      if MercatorWeb.Presence.available_count() == 0,
        do:
          %{conversation_id: conversation.id} |> SendNewConversationNotice.new() |> Oban.insert!()

      PhoneNotifications.new_conversation(conversation.id)
      {:ok, conversation}
    end
  end

  @doc "The customer writes a message in their conversation."
  def post(owner, conversation_id, body) do
    case get(owner, conversation_id) do
      %Conversation{} = conversation ->
        with {:ok, message} <-
               create_message(conversation, %{
                 sender_kind: :customer,
                 sender_id: user_id(owner),
                 body: body
               }) do
          PhoneNotifications.customer_message(conversation, message)
          {:ok, message}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc "The owner's conversation with this id, or nil."
  def get(owner, id) do
    Conversation
    |> filter_owner(owner)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(authorize?: false)
  end

  @doc """
  Nobody answered in time (#95): the customer leaves an email address or a
  phone number. The conversation keeps waiting; the desk and the shop's
  email address are told.
  """
  def request_callback(owner, conversation_id, kind, contact) do
    with %Conversation{} = conversation <- get(owner, conversation_id),
         {:ok, conversation} <-
           Ash.update(conversation, %{callback_kind: kind, callback_contact: contact},
             action: :request_callback,
             authorize?: false
           ) do
      create_message(conversation, %{sender_kind: :system, body: callback_note(conversation)})

      %{conversation_id: conversation.id}
      |> SendCallbackRequest.new()
      |> Oban.insert!()

      broadcast("conversation:#{conversation.id}", {:conversation, conversation})
      broadcast("desk", {:conversation, conversation})
      {:ok, conversation}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp callback_note(%{callback_kind: :email, callback_contact: contact}),
    do:
      Gettext.gettext(MercatorWeb.Gettext, "Reply by email requested: %{contact}",
        contact: contact
      )

  defp callback_note(%{callback_contact: contact}),
    do:
      Gettext.gettext(MercatorWeb.Gettext, "Callback requested by phone: %{contact}",
        contact: contact
      )

  @doc "How long a customer waits for a consultant before being offered a callback (#95)."
  def wait_seconds, do: Application.get_env(:mercator, :consulting_wait_seconds, 180)

  @doc "The customer is now on `path`; the consultant sees it live."
  def visit(owner, conversation_id, path) when is_binary(path) do
    with %Conversation{} = conversation <- get(owner, conversation_id),
         true <- conversation.current_page != path,
         {:ok, conversation} <-
           Ash.update(conversation, %{current_page: String.slice(path, 0, 500)},
             action: :visit,
             authorize?: false
           ) do
      broadcast("conversation:#{conversation.id}", {:visit, conversation.current_page})
      {:ok, conversation}
    else
      false -> :unchanged
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc "The customer ends the conversation."
  def close(owner, conversation_id) do
    with %Conversation{} = conversation <- get(owner, conversation_id),
         {:ok, conversation} <- Ash.update(conversation, %{}, action: :close, authorize?: false) do
      broadcast("conversation:#{conversation.id}", {:conversation, conversation})
      broadcast("desk", {:conversation, conversation})
      {:ok, conversation}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  The customer rates their closed conversation (#101) with 1 to 5 stars
  and an optional comment; once.
  """
  def rate(owner, conversation_id, rating, comment \\ nil) do
    with %Conversation{} = conversation <- get(owner, conversation_id),
         {:ok, conversation} <-
           Ash.update(conversation, %{rating: rating, rating_comment: comment},
             action: :rate,
             authorize?: false
           ) do
      broadcast("desk", {:conversation, conversation})
      {:ok, conversation}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc "Whether the customer is asked to rate a closed conversation: it was answered and is not rated."
  def rateable?(%Conversation{state: :closed, consultant_id: id, rated_at: nil})
      when not is_nil(id),
      do: true

  def rateable?(_conversation), do: false

  @doc """
  The customer asks for a call (phase 10, #141), also while still waiting
  for a consultant (#155), when no call is open. The desk is told; the
  consultant decides to call.
  """
  def request_call(owner, conversation_id) do
    with %Conversation{state: state} = conversation when state in [:waiting, :active] <-
           get(owner, conversation_id),
         nil <- Calls.open_call(conversation.id),
         {:ok, conversation} <- mark_call_requested(conversation) do
      broadcast("conversation:#{conversation.id}", {:conversation, conversation})
      broadcast("desk", {:conversation, conversation})
      broadcast("desk", {:call_requested, conversation.id})
      {:ok, conversation}
    else
      %Call{} -> {:error, :call_open}
      %Conversation{} -> {:error, :closed}
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp mark_call_requested(conversation) do
    with {:ok, conversation} <-
           Ash.update(conversation, %{}, action: :request_call, authorize?: false),
         {:ok, _message} <-
           create_message(conversation, %{sender_kind: :system, body: gettext("Call requested")}),
         do: {:ok, conversation}
  end

  @doc "The customer answers a ringing call in their conversation."
  def accept_call(owner, call_id) do
    with {:ok, %Call{state: :ringing} = call} <- own_call(owner, call_id),
         {:ok, call} <- Ash.update(call, %{}, action: :accept, authorize?: false) do
      Calls.broadcast(call)
      {:ok, call}
    else
      {:ok, %Call{}} -> {:error, :not_ringing}
      error -> error
    end
  end

  @doc "The customer declines a ringing call, or hangs up an active one."
  def hang_up_call(owner, call_id) do
    case own_call(owner, call_id) do
      {:ok, %Call{state: :ringing} = call} -> Calls.finish(call, :declined)
      {:ok, %Call{state: :active} = call} -> Calls.finish(call, :completed)
      {:ok, %Call{}} -> {:error, :ended}
      error -> error
    end
  end

  # the call, if it belongs to one of the owner's conversations
  defp own_call(owner, call_id) do
    with {:ok, call} <- Ash.get(Call, call_id, authorize?: false),
         %Conversation{} <- get(owner, call.conversation_id) do
      {:ok, call}
    else
      _not_found_or_not_own -> {:error, :not_found}
    end
  end

  @doc "Stores a message, marks activity and tells everyone in the conversation."
  def create_message(conversation, attrs) do
    with {:ok, message} <-
           Ash.create(Message, Map.put(attrs, :conversation_id, conversation.id),
             action: :post,
             authorize?: false
           ) do
      Ash.update!(conversation, %{}, action: :touch, authorize?: false)
      message = Ash.load!(message, message_loads(), authorize?: false)
      broadcast("conversation:#{conversation.id}", {:message, message})
      {:ok, message}
    end
  end

  @doc "What is loaded with messages: sender and attachments (product as on listings, file, offer)."
  def message_loads, do: [:sender, :asset, :offer, product: Listing.loads()]

  @doc "Receive the updates of a conversation."
  def subscribe(conversation_id),
    do: Phoenix.PubSub.subscribe(@pubsub, "conversation:#{conversation_id}")

  @doc "At sign-in (#94): the visitor's conversations become the user's."
  def merge(token, user) when is_binary(token) do
    Conversation
    |> filter_owner({:session, token})
    |> Ash.read!(authorize?: false)
    |> Enum.each(
      &Ash.update!(&1, %{customer_id: user.id}, action: :move_to_user, authorize?: false)
    )
  end

  def merge(_token, _user), do: :ok

  @doc false
  def broadcast(topic, message), do: Phoenix.PubSub.broadcast(@pubsub, topic, message)

  defp filter_owner(query, {:user, user}), do: Ash.Query.filter(query, customer_id == ^user.id)

  defp filter_owner(query, {:session, token}) when is_binary(token),
    do: Ash.Query.filter(query, session_token == ^token and is_nil(customer_id))

  defp filter_owner(query, _owner), do: Ash.Query.filter(query, false)

  defp owner_attrs({:user, user}), do: %{customer_id: user.id}
  defp owner_attrs({:session, token}), do: %{session_token: token}

  defp user_id({:user, user}), do: user.id
  defp user_id(_owner), do: nil
end
