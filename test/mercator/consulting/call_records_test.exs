defmodule Mercator.Consulting.CallRecordsTest do
  # Calls in a conversation (phase 10, step 2): ringing, answering, hanging
  # up, missed calls, who may call, and the line in the chat
  use Mercator.DataCase, async: true
  use Oban.Testing, repo: Mercator.Repo

  import Mercator.AccountsFixtures

  alias Mercator.Consulting.{Call, Calls, Conversations, Desk}
  alias Mercator.Consulting.Workers.ExpireCall

  setup do
    owner = {:session, "token-#{System.unique_integer([:positive])}"}
    consultant = user_fixture(roles: [:sales])
    {:ok, conversation} = Conversations.start(owner, "Können Sie mich anrufen?")
    {:ok, conversation} = Desk.take(conversation, consultant)
    Conversations.subscribe(conversation.id)

    %{owner: owner, consultant: consultant, conversation: conversation}
  end

  defp system_messages(owner) do
    for %{sender_kind: :system, body: body} <- Conversations.current(owner).messages, do: body
  end

  test "the consultant calls, the customer answers and hangs up", ctx do
    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    assert %Call{state: :ringing, video: true} = call
    assert call.consultant_id == ctx.consultant.id
    assert_receive {:call, %Call{state: :ringing}}
    assert_enqueued worker: ExpireCall, args: %{call_id: call.id}
    assert Calls.open_call(ctx.conversation.id).id == call.id

    {:ok, call} = Conversations.accept_call(ctx.owner, call.id)
    assert call.state == :active and call.answered_at
    assert_receive {:call, %Call{state: :active}}

    {:ok, call} = Conversations.hang_up_call(ctx.owner, call.id)
    assert %Call{state: :ended, end_reason: :completed} = call
    assert_receive {:call, %Call{state: :ended}}
    assert Calls.open_call(ctx.conversation.id) == nil

    assert Calls.summary(call) in system_messages(ctx.owner)
    assert Calls.summary(call) =~ ~r/\d\d:\d\d–\d\d:\d\d/
  end

  test "declined, cancelled and hung up by the consultant", ctx do
    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant, false)
    assert {:ok, %Call{end_reason: :declined}} = Conversations.hang_up_call(ctx.owner, call.id)

    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    assert {:ok, %Call{end_reason: :cancelled}} = Desk.hang_up(call, ctx.consultant)

    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    {:ok, _} = Conversations.accept_call(ctx.owner, call.id)
    # the consultant's copy still says "ringing": the current state decides
    assert {:ok, %Call{end_reason: :completed}} = Desk.hang_up(call, ctx.consultant)
    assert {:error, :ended} = Desk.hang_up(call, ctx.consultant)
  end

  test "a call nobody answers ends as missed; an answered one keeps running", ctx do
    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    assert :ok = perform_job(ExpireCall, %{call_id: call.id})
    assert %Call{state: :ended, end_reason: :missed} = Ash.get!(Call, call.id, authorize?: false)
    assert Calls.summary(%Call{end_reason: :missed}) in system_messages(ctx.owner)

    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    {:ok, _} = Conversations.accept_call(ctx.owner, call.id)
    assert :ok = perform_job(ExpireCall, %{call_id: call.id})
    assert %Call{state: :active} = Ash.get!(Call, call.id, authorize?: false)
  end

  test "a call ends once, even if two hang up at the same moment", ctx do
    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)

    # both still hold the ringing call
    assert {:ok, %Call{end_reason: :cancelled}} = Calls.finish(call, :cancelled)
    assert {:error, _stale} = Calls.finish(call, :missed)

    assert Enum.count(
             system_messages(ctx.owner),
             &(&1 == Calls.summary(%Call{end_reason: :missed}))
           ) ==
             1
  end

  test "one call at a time, only by the conversation's consultant", ctx do
    {:ok, _call} = Desk.call(ctx.conversation, ctx.consultant)
    assert {:error, %Ash.Error.Invalid{}} = Desk.call(ctx.conversation, ctx.consultant)

    colleague = user_fixture(roles: [:sales])
    assert {:error, :not_your_conversation} = Desk.call(ctx.conversation, colleague)

    {:ok, waiting} = Conversations.start(ctx.owner, "Noch eine Frage")
    assert {:error, :not_your_conversation} = Desk.call(waiting, ctx.consultant)
  end

  test "customers cannot create calls themselves; staff read them", ctx do
    customer = user_fixture()

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(Call, %{conversation_id: ctx.conversation.id},
               action: :start,
               actor: customer
             )

    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    assert {:ok, _} = Ash.get(Call, call.id, actor: user_fixture(roles: [:sales_manager]))
    assert {:error, _} = Ash.get(Call, call.id, actor: customer)
  end

  test "nobody else answers or hangs up the customer's call", ctx do
    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    stranger = {:session, "token-#{System.unique_integer([:positive])}"}

    assert {:error, :not_found} = Conversations.accept_call(stranger, call.id)
    assert {:error, :not_found} = Conversations.hang_up_call(stranger, call.id)
    assert {:error, :not_found} = Conversations.accept_call(ctx.owner, "not-a-uuid")
    assert {:error, :not_your_call} = Desk.hang_up(call, user_fixture(roles: [:sales]))
  end

  test "the customer asks for a call (#141)", ctx do
    Phoenix.PubSub.subscribe(Mercator.PubSub, "desk")
    id = ctx.conversation.id

    assert :ok = Conversations.request_call(ctx.owner, id)
    assert_receive {:call_requested, ^id}
    assert "Anruf erbeten" in system_messages(ctx.owner)

    {:ok, _call} = Desk.call(ctx.conversation, ctx.consultant)
    assert {:error, :call_open} = Conversations.request_call(ctx.owner, id)

    {:ok, waiting} = Conversations.start(ctx.owner, "Noch eine Frage")
    assert {:error, :no_consultant} = Conversations.request_call(ctx.owner, waiting.id)
  end

  test "ending the call ends its media and their connections", ctx do
    {:ok, call} = Desk.call(ctx.conversation, ctx.consultant)
    {:ok, _} = Conversations.accept_call(ctx.owner, call.id)
    :ok = Calls.join(ctx.conversation.id, :customer)

    [{room, _}] = Registry.lookup(Mercator.Consulting.Calls.Registry, ctx.conversation.id)
    %{participants: %{customer: %{pc: pc}}} = :sys.get_state(room)
    room_ref = Process.monitor(room)
    pc_ref = Process.monitor(pc)

    {:ok, _} = Conversations.hang_up_call(ctx.owner, call.id)
    assert_receive {:DOWN, ^room_ref, :process, _, :normal}
    assert_receive {:DOWN, ^pc_ref, :process, _, _}
  end
end
