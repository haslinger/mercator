defmodule MercatorWeb.ChatLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Consulting.Conversations
  alias MercatorWeb.ChatLive

  defp visitor_conn(conn) do
    token = "visitor-#{System.unique_integer([:positive])}"
    {Plug.Test.init_test_session(conn, %{"basket_token" => token}), {:session, token}}
  end

  test "shop pages render the chat; admin and sign-in pages do not", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200) =~ ~s(id="chat-widget")
    refute build_conn() |> get(~p"/sign-in") |> html_response(200) =~ ~s(id="chat-widget")
    refute ChatLive.show?(%Plug.Conn{request_path: "/admin/pages"})
  end

  test "a visitor asks a question and gets the consultant's answer live", %{conn: conn} do
    {conn, owner} = visitor_conn(conn)
    {:ok, view, _html} = live_isolated(conn, ChatLive)

    assert has_element?(view, "#chat-panel.hidden")
    view |> element("#chat-toggle") |> render_click()
    refute has_element?(view, "#chat-panel.hidden")
    assert has_element?(view, "#chat-intro")

    view
    |> form("#chat-form", chat: %{body: "Wie viel Lärche für 40 m²?"})
    |> render_submit(%{"page" => "/products/terrassendiele"})

    assert has_element?(view, "#chat-messages .chat-end", "Wie viel Lärche")
    assert has_element?(view, "#chat-status", "wir verbinden Sie")

    conversation = Conversations.current(owner)
    assert conversation.page == "/products/terrassendiele"

    consultant = user_fixture(roles: [:sales])

    Conversations.create_message(conversation, %{
      sender_kind: :consultant,
      sender_id: consultant.id,
      body: "Rund 1,1 m² Dielen pro m² Fläche."
    })

    assert render(view) =~ "Rund 1,1 m²"
    assert has_element?(view, "#chat-messages .chat-start", "Rund 1,1")
  end

  test "unread answers are counted while the panel is closed", %{conn: conn} do
    {conn, owner} = visitor_conn(conn)
    {:ok, conversation} = Conversations.start(owner, "Hallo")
    {:ok, view, _html} = live_isolated(conn, ChatLive)

    Conversations.create_message(conversation, %{sender_kind: :consultant, body: "Grüß Gott!"})
    assert has_element?(view, "#chat-unread", "1")

    view |> element("#chat-toggle") |> render_click()
    refute has_element?(view, "#chat-unread")
    assert has_element?(view, "#chat-messages", "Grüß Gott!")
    # the earlier message (e.g. from before a page change) is there too
    assert has_element?(view, "#chat-messages .chat-end", "Hallo")
  end

  test "the product button opens the chat about the product", %{conn: conn} do
    {conn, owner} = visitor_conn(conn)
    {:ok, view, _html} = live_isolated(conn, ChatLive)

    render_hook(view, "open", %{
      "subject" => "Gartenhaus Kompakt",
      "product_id" => nil,
      "page" => "/products/gh"
    })

    assert has_element?(view, "#chat-intro", "Gartenhaus Kompakt")

    view |> form("#chat-form", chat: %{body: "Mit Fundament?"}) |> render_submit()
    assert Conversations.current(owner).subject == "Gartenhaus Kompakt"
  end

  test "signed-in customers chat under their account; ending closes it", %{conn: conn} do
    user = user_fixture()
    {:ok, view, _html} = live_isolated(log_in_user(conn, user), ChatLive)

    view |> element("#chat-toggle") |> render_click()
    view |> form("#chat-form", chat: %{body: "Hallo"}) |> render_submit()
    assert Conversations.current({:user, user})

    view |> element("#chat-end") |> render_click()
    assert Conversations.current({:user, user}) == nil
  end
end
