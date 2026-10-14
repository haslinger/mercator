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

  alias Mercator.Consulting.{Conversation, Conversations, Offers}
  alias Mercator.Sales.{BasketPricing, Baskets, Order}

  @loads [:customer, :consultant, :product]

  @doc "Waiting conversations, the longest waiting first."
  def waiting(actor) do
    Conversation
    |> Ash.Query.filter(state == :waiting)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(actor: actor)
    |> Ash.load!(@loads, authorize?: false)
  end

  @doc "Active conversations, newest activity first."
  def active(actor) do
    Conversation
    |> Ash.Query.filter(state == :active)
    |> Ash.Query.sort(last_message_at: :desc_nils_last)
    |> Ash.read!(actor: actor)
    |> Ash.load!(@loads, authorize?: false)
  end

  @doc """
  A conversation with its messages, for the desk. Conversations are read
  with the actor's policies; customer, consultant and messages of a
  readable conversation without (sales staff may not read user accounts).
  """
  def get(id, actor) do
    Conversation
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, %Conversation{} = conversation} ->
        Ash.load(conversation, @loads ++ [messages: Conversations.message_loads()],
          authorize?: false
        )

      other ->
        other
    end
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

  @doc "The consultant recommends a product, with an optional note."
  def recommend(conversation, actor, product_id, note \\ nil) do
    Conversations.create_message(conversation, %{
      sender_kind: :consultant,
      sender_id: actor.id,
      product_id: product_id,
      body: note
    })
  end

  @doc "The consultant shares a link (a shop page or a website) with an optional title."
  def share_link(conversation, actor, url, title \\ nil) do
    Conversations.create_message(conversation, %{
      sender_kind: :consultant,
      sender_id: actor.id,
      link_url: String.trim(url),
      link_title: title
    })
  end

  @doc "The consultant shares a file of the media library (an image or a PDF)."
  def share_file(conversation, actor, asset_id) do
    Conversations.create_message(conversation, %{
      sender_kind: :consultant,
      sender_id: actor.id,
      asset_id: asset_id
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

  @doc """
  What the consultant sees about the customer (step 3): online status,
  the basket with live prices (`Mercator.Sales.BasketPricing`) and the
  last orders and offers of a signed-in customer, and the customer's
  earlier conversations.
  """
  def context(conversation, actor) do
    owner = basket_owner(conversation)

    basket =
      owner
      |> Baskets.get()
      |> then(&(&1 && BasketPricing.calculate(&1)))

    orders =
      if conversation.customer_id do
        Order
        |> Ash.Query.filter(user_id == ^conversation.customer_id)
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(5)
        |> Ash.read!(actor: actor)
      else
        []
      end

    offers =
      if conversation.customer_id,
        do: Offers.for_customer(conversation.customer_id, actor),
        else: []

    %{
      online?: MercatorWeb.Presence.customer_online?(conversation.id),
      basket: basket,
      orders: orders,
      offers: offers,
      earlier: earlier(conversation, actor)
    }
  end

  @doc """
  Closed conversations, newest first, for the archive. `filters`:
  `:query` (customer name or email, or subject), `:consultant_id`.
  `page` as for `Ash.read/2`.
  """
  def archive(actor, filters \\ %{}, page \\ [limit: 25]) do
    page =
      Conversation
      |> Ash.Query.filter(state == :closed)
      |> filter_consultant(filters[:consultant_id])
      |> filter_text(String.trim(filters[:query] || ""))
      |> Ash.Query.sort(closed_at: :desc_nils_last, updated_at: :desc)
      |> Ash.read!(actor: actor, page: page)

    %{page | results: Ash.load!(page.results, @loads, authorize?: false)}
  end

  defp filter_consultant(query, nil), do: query
  defp filter_consultant(query, id), do: Ash.Query.filter(query, consultant_id == ^id)

  defp filter_text(query, ""), do: query

  # customers are searched separately: sales staff may not read user accounts
  defp filter_text(query, text) do
    customer_ids = text |> Offers.find_customers() |> Enum.map(& &1.id)
    pattern = "%" <> String.replace(text, ~r/[\\%_]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      customer_id in ^customer_ids or fragment("? ILIKE ?", subject, ^pattern)
    )
  end

  @doc "The customer's earlier, closed conversations (newest first)."
  def earlier(conversation, actor) do
    Conversation
    |> Ash.Query.filter(state == :closed and id != ^conversation.id)
    |> filter_same_customer(conversation)
    |> Ash.Query.sort(closed_at: :desc_nils_last, inserted_at: :desc)
    |> Ash.Query.limit(5)
    |> Ash.read!(actor: actor)
    |> Ash.load!([:consultant], authorize?: false)
  end

  defp filter_same_customer(query, %{customer_id: id}) when not is_nil(id),
    do: Ash.Query.filter(query, customer_id == ^id)

  defp filter_same_customer(query, %{session_token: token}) when is_binary(token),
    do: Ash.Query.filter(query, session_token == ^token)

  defp filter_same_customer(query, _conversation), do: Ash.Query.filter(query, false)

  @doc "The basket owner of the conversation's customer (see `Mercator.Sales.Baskets`)."
  def basket_owner(%{customer_id: id}) when not is_nil(id), do: {:user, %{id: id}}
  def basket_owner(%{session_token: token}), do: {:session, token}

  @doc "How staff and customers are named in the desk and the chat."
  def display_name(%{name: name}) when is_binary(name) and name != "", do: name
  def display_name(%{email: email}) when not is_nil(email), do: to_string(email)
  def display_name(_user), do: gettext("Visitor")
end
