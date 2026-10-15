defmodule MercatorWeb.ChatLiveTest do
  use MercatorWeb.ConnCase, async: true
  use Oban.Testing, repo: Mercator.Repo

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Consulting.{Conversations, Desk}
  alias Mercator.Consulting.Workers.SendCallbackRequest
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
    assert has_element?(view, ~s(#chat-help a[href="/help"]))

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

  test "a link with ?chat=open (reply email) opens the panel", %{conn: conn} do
    {conn, _owner} = visitor_conn(conn)
    {:ok, closed, _html} = live_isolated(conn, ChatLive)
    refute has_element?(closed, "#chat-panel.flex")

    {:ok, open, _html} = live_isolated(conn, ChatLive, session: %{"open" => true})
    assert has_element?(open, "#chat-panel.flex")

    html = conn |> get(~p"/?chat=open") |> html_response(200)
    assert html =~ ~s(id="chat-panel")
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

  describe "rating (#101)" do
    setup %{conn: conn} do
      {conn, owner} = visitor_conn(conn)
      {:ok, view, _html} = live_isolated(conn, ChatLive)
      view |> element("#chat-toggle") |> render_click()
      view |> form("#chat-form", chat: %{body: "Welches Öl für Lärche?"}) |> render_submit()
      %{view: view, owner: owner, conversation: Conversations.current(owner)}
    end

    test "after advice the customer rates with stars and a comment", context do
      consultant = user_fixture(roles: [:sales])
      {:ok, _} = Desk.post(context.conversation, consultant, "Hartwachsöl.")
      conversation = Conversations.get(context.owner, context.conversation.id)
      {:ok, _} = Desk.close(conversation, consultant)

      assert has_element?(context.view, "#chat-rating")

      context.view
      |> form("#chat-rating", %{"rating" => "4", "comment" => "Sehr hilfreich"})
      |> render_submit()

      assert has_element?(context.view, "#chat-rated")
      refute has_element?(context.view, "#chat-rating")

      rated = Conversations.get(context.owner, context.conversation.id)
      assert rated.rating == 4
      assert rated.rating_comment == "Sehr hilfreich"
      assert {:error, _} = Conversations.rate(context.owner, rated.id, 5)
    end

    test "nothing to rate when nobody answered", %{view: view} do
      view |> element("#chat-end") |> render_click()
      refute has_element?(view, "#chat-rating")
      refute has_element?(view, "#chat-panel.flex")
    end
  end

  describe "nobody answers (#95)" do
    test "after the waiting time the customer may leave email or phone", %{conn: conn} do
      {conn, owner} = visitor_conn(conn)
      {:ok, view, _html} = live_isolated(conn, ChatLive)
      view |> element("#chat-toggle") |> render_click()
      view |> form("#chat-form", chat: %{body: "Brauche ein Angebot"}) |> render_submit()

      # the countdown in the browser runs out
      render_hook(view, "waited", %{})
      assert has_element?(view, "#chat-callback")

      view
      |> form("#chat-callback", %{"kind" => "phone", "contact" => "kein Telefon"})
      |> render_submit()

      assert has_element?(view, "#chat-callback-error")

      view
      |> form("#chat-callback", %{"kind" => "phone", "contact" => "+43 664 1234567"})
      |> render_submit()

      assert has_element?(view, "#chat-callback-done", "+43 664 1234567")
      assert has_element?(view, "#chat-messages", "Rückruf gewünscht per Telefon")

      conversation = Conversations.current(owner)
      assert conversation.state == :waiting
      assert conversation.callback_kind == :phone

      assert_enqueued worker: SendCallbackRequest,
                      args: %{conversation_id: conversation.id}
    end

    test "the shop gets an email with the request and the questions", %{conn: conn} do
      {_conn, owner} = visitor_conn(conn)

      {:ok, conversation} =
        Conversations.start(owner, "Gartenhaus mit Fundament?", %{subject: "Gartenhaus"})

      {:ok, _} =
        Conversations.request_callback(owner, conversation.id, :email, "karl@example.com")

      email =
        SendCallbackRequest.email(
          Ash.load!(Conversations.current(owner), [:customer, messages: [:sender]],
            authorize?: false
          )
        )

      assert email.subject =~ "karl@example.com"
      assert email.text_body =~ "> Gartenhaus mit Fundament?"
      assert email.text_body =~ "/admin/desk/#{conversation.id}"
    end
  end
end
