defmodule Mercator.Seeds.ConsultingTest do
  use Mercator.DataCase, async: false

  alias Mercator.Consulting.{Conversation, Offer}
  alias Mercator.Seeds

  setup do
    Seeds.run()
    :ok
  end

  defp conversations, do: Ash.read!(Conversation, authorize?: false, load: [:messages])
  defp offers, do: Ash.read!(Offer, authorize?: false, load: [:order])

  test "creates conversations in every state, backdated, without emails" do
    conversations = conversations()

    assert conversations |> Enum.map(& &1.state) |> Enum.frequencies() ==
             %{closed: 3, active: 1, waiting: 1}

    assert Enum.count(conversations, & &1.rating) == 2
    assert Enum.any?(conversations, &(&1.callback_kind == :phone and &1.session_token))

    for conversation <- conversations do
      times = Enum.map(conversation.messages, & &1.inserted_at)
      assert times == Enum.sort(times, DateTime)
      assert Enum.all?(times, &(DateTime.compare(&1, conversation.inserted_at) != :lt))
      assert DateTime.compare(conversation.last_message_at, DateTime.utc_now()) == :lt
    end

    oldest = Enum.min_by(conversations, & &1.inserted_at, DateTime)
    assert DateTime.diff(DateTime.utc_now(), oldest.inserted_at, :day) >= 59

    refute Repo.exists?(Oban.Job)
  end

  test "creates offers in different states, one revised and ordered" do
    offers = offers()

    assert offers |> Enum.map(& &1.state) |> Enum.sort() ==
             Enum.sort([:revised, :accepted, :expired, :sent, :pending_approval])

    accepted = Enum.find(offers, &(&1.state == :accepted))
    assert accepted.version == 2
    assert accepted.order
    assert Enum.find(offers, &(&1.state == :revised)).number == accepted.number

    sent = Enum.find(offers, &(&1.state == :sent))
    assert Offer.acceptable?(sent)
  end

  test "is idempotent" do
    Seeds.run()
    assert length(conversations()) == 5
    assert length(offers()) == 5
  end
end
