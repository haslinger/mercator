defmodule MercatorWeb.ContactOptionsTest do
  # Writing or talking (#154–#157): the chat's start screen, a conversation
  # that starts with a call request, the "Kontaktwege" block and whether a
  # consultant is at the desk. Presence is global: not async.
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Consulting.Conversations
  alias Mercator.Content
  alias MercatorWeb.{ChatLive, Presence}

  defp visitor_conn(conn) do
    token = "visitor-#{System.unique_integer([:positive])}"
    {Plug.Test.init_test_session(conn, %{"basket_token" => token}), {:session, token}}
  end

  # the test hears the same presence diffs as the LiveViews
  setup do
    Phoenix.PubSub.subscribe(Mercator.PubSub, Presence.topic())
  end

  # a consultant at the desk, tracked by the test process
  defp at_desk do
    key = "consultant-#{System.unique_integer([:positive])}"
    {:ok, _ref} = Presence.track(self(), Presence.topic(), key, %{available: true})

    assert_receive %Phoenix.Socket.Broadcast{
      event: "presence_diff",
      payload: %{joins: %{^key => _}}
    }

    key
  end

  defp leave_desk(key) do
    :ok = Presence.untrack(self(), Presence.topic(), key)

    assert_receive %Phoenix.Socket.Broadcast{
      event: "presence_diff",
      payload: %{leaves: %{^key => _}}
    }
  end

  describe "the chat" do
    test "offers writing and talking; talking starts a conversation with a call request",
         %{conn: conn} do
      {conn, owner} = visitor_conn(conn)
      {:ok, view, _html} = live_isolated(conn, ChatLive)

      assert has_element?(view, "#chat-way-write")
      assert has_element?(view, "#chat-availability[data-available=false]")
      refute has_element?(view, "#chat-available")

      view |> element("#chat-way-call") |> render_click()

      conversation = Conversations.current(owner)
      assert conversation.call_requested_at
      assert has_element?(view, "#chat-messages .chat-start", "Anruf erbeten")
      assert has_element?(view, "#chat-request-call[disabled]", "Anruf erbeten")
      # nobody at the desk: the callback, by phone
      assert has_element?(view, "#chat-callback input[value=phone][checked]")
    end

    test "shows when a consultant is available, live", %{conn: conn} do
      {conn, _owner} = visitor_conn(conn)
      {:ok, view, _html} = live_isolated(conn, ChatLive)
      refute has_element?(view, "#chat-available")

      key = at_desk()
      assert has_element?(view, "#chat-available")
      assert has_element?(view, "#chat-availability[data-available=true]")

      view |> element("#chat-way-call") |> render_click()
      assert has_element?(view, "#chat-countdown", "Gleich ruft Sie jemand hier an")

      leave_desk(key)
      refute has_element?(view, "#chat-available")
    end

    test "who wrote first may still ask to talk while waiting", %{conn: conn} do
      {conn, owner} = visitor_conn(conn)
      key = at_desk()
      {:ok, view, _html} = live_isolated(conn, ChatLive)

      view |> form("#chat-form", chat: %{body: "Hallo"}) |> render_submit()
      assert has_element?(view, "#chat-request-call", "Lieber sprechen?")

      view |> element("#chat-request-call") |> render_click()
      assert has_element?(view, "#chat-request-call[disabled]")
      assert Conversations.current(owner).call_requested_at
      leave_desk(key)
    end

    test "the block's buttons open the panel to write or to talk", %{conn: conn} do
      {conn, owner} = visitor_conn(conn)
      {:ok, view, _html} = live_isolated(conn, ChatLive)

      render_hook(view, "open", %{"start" => "write"})
      refute has_element?(view, "#chat-panel.hidden")
      assert_push_event(view, "chat:focus", %{})
      assert Conversations.current(owner) == nil

      render_hook(view, "open", %{"start" => "call", "subject" => "Lärche"})
      assert %{subject: "Lärche", call_requested_at: %DateTime{}} = Conversations.current(owner)
    end
  end

  describe "the block" do
    setup do
      editor = user_fixture(roles: [:contentmanager])

      %{
        title: %{"de" => "Beratung"},
        slug: "wege-zur-beratung",
        blocks: [
          %{
            type: "contact_options",
            headline: %{"de" => "Wie möchten Sie beraten werden?"},
            message_link: "/pages/kontakt"
          }
        ]
      }
      |> Content.create_page!(actor: editor)
      |> Content.publish_page!(actor: editor)

      :ok
    end

    test "shows the ways to get advice and who is available, live", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/pages/wege-zur-beratung")

      assert has_element?(view, "[id$=-write] button", "Chat starten")
      assert has_element?(view, "[id$=-call] button", "Rückruf anfordern")
      assert has_element?(view, ~s([id$=-message] a[href="/pages/kontakt"]))
      assert has_element?(view, "[id$=-availability][data-available=false]")

      key = at_desk()
      assert has_element?(view, "[id$=-availability][data-available=true]")
      assert has_element?(view, "[id$=-call] button", "Anrufen lassen")

      leave_desk(key)
      assert has_element?(view, "[id$=-availability][data-available=false]")
    end

    test "with the shop's phone number when the brand has one", %{conn: conn} do
      phone = Mercator.Brand.get(:phone)
      {:ok, view, _html} = live(conn, ~p"/pages/wege-zur-beratung")

      if phone,
        do: assert(has_element?(view, ~s([id$=-phone] a[href^="tel:"]), phone)),
        else: refute(has_element?(view, "[id$=-phone]"))
    end
  end

  test "the desk marks a conversation whose customer would rather talk", %{conn: conn} do
    consultant = user_fixture(roles: [:sales])
    {:ok, conversation} = Conversations.start_call({:session, "visitor-desk-call"})

    {:ok, view, _html} =
      conn |> log_in_user(consultant) |> live(~p"/admin/desk/#{conversation.id}")

    assert has_element?(view, "#desk-call-requested-#{conversation.id}")
    assert has_element?(view, "#conversation-call-requested")
  end
end
