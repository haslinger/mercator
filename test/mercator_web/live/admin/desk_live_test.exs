defmodule MercatorWeb.Admin.DeskLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Consulting.Conversations
  alias MercatorWeb.{ChatLive, Presence}

  defp visitor_conn do
    token = "visitor-#{System.unique_integer([:positive])}"
    {Plug.Test.init_test_session(build_conn(), %{"basket_token" => token}), {:session, token}}
  end

  setup %{conn: conn} do
    consultant = user_fixture(roles: [:sales]) |> Ash.Seed.update!(%{name: "Sepp Fuchs"})
    %{conn: log_in_user(conn, consultant), consultant: consultant}
  end

  test "only sales staff and administrators" do
    for roles <- [[], [:contentmanager]] do
      conn = log_in_user(build_conn(), user_fixture(roles: roles))
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/desk")
    end
  end

  test "availability is shared with Presence", %{conn: conn, consultant: consultant} do
    {:ok, view, _html} = live(conn, ~p"/admin/desk")
    assert has_element?(view, "#availability", "Abwesend")

    view |> element("#availability") |> render_click()
    assert has_element?(view, "#availability", "Verfügbar")

    assert %{metas: [%{available: true}]} = Presence.get_by_key(Presence.topic(), consultant.id)
  end

  test "a new conversation appears, the consultant takes it and both chat live", %{conn: conn} do
    {:ok, desk, _html} = live(conn, ~p"/admin/desk")
    desk |> element("#availability") |> render_click()

    {customer_conn, owner} = visitor_conn()
    {:ok, chat, _html} = live_isolated(customer_conn, ChatLive)
    chat |> element("#chat-toggle") |> render_click()
    chat |> form("#chat-form", chat: %{body: "Brauche Beratung zu Lärche"}) |> render_submit()

    conversation = Conversations.current(owner)
    assert_push_event(desk, "desk:notify", %{title: "Neues Gespräch"})
    assert has_element?(desk, "#waiting-list #desk-conversation-#{conversation.id}")

    desk |> element("#desk-conversation-#{conversation.id}") |> render_click()
    assert has_element?(desk, "#desk-messages", "Brauche Beratung zu Lärche")

    desk |> element("#take") |> render_click()
    assert has_element?(desk, "#mine-list #desk-conversation-#{conversation.id}")
    assert has_element?(chat, "#chat-status", "Sepp Fuchs")
    assert has_element?(chat, "#chat-messages", "Sepp Fuchs berät Sie jetzt.")

    desk
    |> form("#reply-form", reply: %{body: "Gerne! Wie groß ist die Terrasse?"})
    |> render_submit()

    assert has_element?(chat, "#chat-messages .chat-start", "Wie groß ist die Terrasse?")

    chat |> form("#chat-form", chat: %{body: "40 m²"}) |> render_submit()
    assert has_element?(desk, "#desk-messages .chat-start", "40 m²")

    desk |> element("#close-conversation") |> render_click()
    refute has_element?(desk, "#desk-conversation-#{conversation.id}")
    assert Conversations.current(owner) == nil
  end

  test "callback requests are marked on the desk", %{conn: conn} do
    {_customer_conn, owner} = visitor_conn()
    {:ok, conversation} = Conversations.start(owner, "Bitte zurückrufen")
    {:ok, _} = Conversations.request_callback(owner, conversation.id, :phone, "+43 1 2345678")

    {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
    assert has_element?(desk, "#desk-conversation-#{conversation.id} .badge", "Rückruf")
    assert has_element?(desk, "#conversation-callback", "+43 1 2345678")
  end
end
