defmodule Mercator.Consulting.ConversationsTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Consulting.Conversations

  defp visitor, do: {:session, "token-#{System.unique_integer([:positive])}"}

  test "a visitor starts a conversation and writes in it (#94)" do
    owner = visitor()
    assert Conversations.current(owner) == nil

    {:ok, conversation} =
      Conversations.start(owner, "Wie viel Lärche für 40 m² Terrasse?", %{
        subject: "Terrassendielen",
        page: "/products/terrassendiele-laerche"
      })

    assert conversation.state == :waiting
    assert conversation.subject == "Terrassendielen"

    assert [%{sender_kind: :customer, body: "Wie viel Lärche für 40 m² Terrasse?"}] =
             conversation.messages

    Conversations.subscribe(conversation.id)
    {:ok, _} = Conversations.post(owner, conversation.id, "Und die Schrauben?")
    assert_receive {:message, %{body: "Und die Schrauben?"}}

    assert length(Conversations.current(owner).messages) == 2
  end

  test "nobody else reaches the conversation" do
    {:ok, conversation} = Conversations.start(visitor(), "Hallo")

    assert {:error, :not_found} = Conversations.post(visitor(), conversation.id, "fremd")

    assert {:error, :not_found} =
             Conversations.post({:user, user_fixture()}, conversation.id, "fremd")

    assert Conversations.get({:session, nil}, conversation.id) == nil
  end

  test "the sales desk hears about new conversations" do
    Phoenix.PubSub.subscribe(Mercator.PubSub, "desk")
    {:ok, conversation} = Conversations.start(visitor(), "Hallo")

    # other async tests broadcast on the same topic
    id = conversation.id
    assert_receive {:conversation, %{id: ^id, state: :waiting}}
  end

  test "closed conversations are no longer current" do
    owner = visitor()
    {:ok, conversation} = Conversations.start(owner, "Hallo")
    {:ok, _} = Conversations.close(owner, conversation.id)

    assert Conversations.current(owner) == nil
  end

  test "at sign-in the visitor's conversation becomes the user's" do
    {:session, token} = owner = visitor()
    {:ok, conversation} = Conversations.start(owner, "Hallo")
    user = user_fixture()

    Conversations.merge(token, user)

    assert Conversations.current(owner) == nil
    assert Conversations.current({:user, user}).id == conversation.id
  end
end
