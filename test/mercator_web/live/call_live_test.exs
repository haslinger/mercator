defmodule MercatorWeb.CallLiveTest do
  # Calls between the customer's chat panel and the sales desk (phase 10,
  # step 3). Not async: the desk follows the global "desk" topic.
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias ExWebRTC.{PeerConnection, SessionDescription}
  alias Mercator.Consulting.{Call, Calls, Conversations, Desk}
  alias MercatorWeb.ChatLive

  # closing connections makes the ICE library log warnings
  @moduletag :capture_log

  setup %{conn: conn} do
    token = "visitor-#{System.unique_integer([:positive])}"
    owner = {:session, token}
    customer_conn = Plug.Test.init_test_session(build_conn(), %{"basket_token" => token})

    consultant = user_fixture(roles: [:sales]) |> Ash.Seed.update!(%{name: "Sepp Fuchs"})
    {:ok, conversation} = Conversations.start(owner, "Rufen Sie mich an?")
    {:ok, conversation} = Desk.take(conversation, consultant)

    {:ok, chat, _html} = live_isolated(customer_conn, ChatLive)
    {:ok, desk, _html} = live(log_in_user(conn, consultant), ~p"/admin/desk/#{conversation.id}")

    %{chat: chat, desk: desk, conversation: conversation, consultant: consultant}
  end

  test "the consultant calls, the customer answers, the media starts, and they hang up", ctx do
    %{chat: chat, desk: desk} = ctx

    desk |> element("#call-video") |> render_click()
    assert has_element?(desk, "#desk-call", "Ruft")
    assert has_element?(desk, ~s(#desk-call-ringback[phx-hook="Ringtone"][data-tone="ringback"]))

    # the call rings in the customer's panel, which opens
    assert render(chat) && has_element?(chat, "#chat-call-ringing", "Sepp Fuchs")
    refute has_element?(chat, "#chat-panel.hidden")
    assert has_element?(chat, ~s(#chat-call-ringing[phx-hook="Ringtone"][data-tone="ring"]))

    chat |> element("#chat-accept-call") |> render_click()
    assert has_element?(chat, ~s(#chat-call-media[phx-hook="Call"][data-video="false"]))

    assert render(desk) &&
             has_element?(desk, ~s(#desk-call-media[phx-hook="Call"][data-video="true"]))

    # the hook has the microphone: the room makes the offer, the browser answers
    render_hook(chat, "call_media_ready", %{})
    assert Calls.participants(ctx.conversation.id) == [:customer]
    assert_push_event(chat, "call:signal", %{"type" => "offer"} = offer)

    {:ok, browser} = PeerConnection.start_link(audio_codecs: [:opus], video_codecs: [:vp8])
    :ok = PeerConnection.set_remote_description(browser, SessionDescription.from_json(offer))
    {:ok, answer} = PeerConnection.create_answer(browser)
    :ok = PeerConnection.set_local_description(browser, answer)
    render_hook(chat, "call_signal", SessionDescription.to_json(answer))

    [{room, _}] = Registry.lookup(Mercator.Consulting.Calls.Registry, ctx.conversation.id)
    %{participants: %{customer: %{pc: pc}}} = :sys.get_state(room)
    assert PeerConnection.get_signaling_state(pc) == :stable

    render_hook(desk, "call_media_ready", %{})
    assert Enum.sort(Calls.participants(ctx.conversation.id)) == [:consultant, :customer]

    # the controls of the call area (step 4)
    for control <- ~w(mute camera screen fullscreen settings mic cam),
        do: assert(has_element?(chat, "#chat-call-media [data-call-#{control}]"))

    # the customer shares the screen: the consultant's hook is told
    render_hook(chat, "call_screen", %{"on" => true})
    assert_push_event(desk, "call:signal", %{"type" => "screen", "state" => "on"})

    chat |> element("#chat-hang-up") |> render_click()
    refute has_element?(chat, "#chat-call")
    render(desk)
    refute has_element?(desk, "#desk-call")
    assert has_element?(desk, "#desk-messages", "Videoanruf")
    assert Calls.participants(ctx.conversation.id) == []
  end

  test "a failed connection ends the call; the details stay on the server", ctx do
    ctx.desk |> element("#call-audio") |> render_click()
    render(ctx.chat)
    ctx.chat |> element("#chat-accept-call") |> render_click()

    failed = %{
      "type" => "state",
      "state" => "failed",
      "details" => "server candidates: host 172.30.0.10:50000"
    }

    send(ctx.chat.pid, {:call_signal, ctx.conversation.id, failed})

    assert_push_event(ctx.chat, "call:signal", pushed)
    assert pushed == %{"type" => "state", "state" => "failed"}
    refute has_element?(ctx.chat, "#chat-call-active")
    assert Calls.open_call(ctx.conversation.id) == nil
  end

  test "an audio call the customer declines", ctx do
    ctx.desk |> element("#call-audio") |> render_click()
    assert render(ctx.chat) && has_element?(ctx.chat, "#chat-call-ringing")

    ctx.chat |> element("#chat-decline-call") |> render_click()
    refute has_element?(ctx.chat, "#chat-call")
    assert render(ctx.desk) && has_element?(ctx.desk, "#desk-messages", "Anruf abgelehnt")
    assert has_element?(ctx.desk, "#call-audio")
  end

  test "the consultant cancels a ringing call", ctx do
    ctx.desk |> element("#call-audio") |> render_click()
    ctx.desk |> element("#desk-cancel-call") |> render_click()

    render(ctx.chat)
    refute has_element?(ctx.chat, "#chat-call")
    assert has_element?(ctx.chat, "#chat-messages", "Verpasster Anruf")
  end

  test "without microphone access the call ends as failed", ctx do
    ctx.desk |> element("#call-audio") |> render_click()
    render(ctx.chat)
    ctx.chat |> element("#chat-accept-call") |> render_click()

    render_hook(ctx.chat, "call_media_error", %{"name" => "NotAllowedError"})
    assert has_element?(ctx.chat, "#chat-call-error", "Mikrofon")
    refute has_element?(ctx.chat, "#chat-call-active")
    conversation_id = ctx.conversation.id

    assert [%Call{end_reason: :failed}] =
             Ash.read!(Call, authorize?: false)
             |> Enum.filter(&(&1.conversation_id == conversation_id))
  end

  test "the customer asks for a call; the desk is notified", ctx do
    ctx.chat |> element("#chat-request-call") |> render_click()
    assert has_element?(ctx.chat, "#chat-request-call[disabled]")
    assert_push_event(ctx.desk, "desk:notify", %{title: "Anruf erbeten"})
  end

  test "colleagues see the call but cannot join it", ctx do
    ctx.desk |> element("#call-audio") |> render_click()
    render(ctx.chat)
    ctx.chat |> element("#chat-accept-call") |> render_click()

    colleague = user_fixture(roles: [:sales])
    path = ~p"/admin/desk/#{ctx.conversation.id}"
    {:ok, other_desk, _html} = live(log_in_user(build_conn(), colleague), path)

    assert has_element?(other_desk, "#conversation-in-call")
    refute has_element?(other_desk, "#desk-call")
    render_hook(other_desk, "call_media_ready", %{})
    assert Calls.participants(ctx.conversation.id) == []
  end

  test "the call stays while the consultant looks at other conversations (#150)", ctx do
    ctx.desk |> element("#call-audio") |> render_click()
    render(ctx.chat)
    ctx.chat |> element("#chat-accept-call") |> render_click()
    render(ctx.desk)
    assert has_element?(ctx.desk, "#desk-call #desk-call-media")
    refute has_element?(ctx.desk, "#desk-call-conversation")

    render_patch(ctx.desk, ~p"/admin/desk")
    assert has_element?(ctx.desk, "#desk-call #desk-call-media")

    assert has_element?(
             ctx.desk,
             ~s(#desk-call-conversation[href="/admin/desk/#{ctx.conversation.id}"])
           )

    assert Calls.open_call(ctx.conversation.id).state == :active

    # a reloaded desk finds the call again
    {:ok, desk, _html} = live(log_in_user(build_conn(), ctx.consultant), ~p"/admin/desk")
    assert has_element?(desk, "#desk-call #desk-call-media")

    desk |> element("#desk-hang-up") |> render_click()
    refute has_element?(desk, "#desk-call")
  end
end
