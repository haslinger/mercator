defmodule MercatorWeb.Admin.DeskLiveTest do
  # the desk follows the global "desk" topic and Presence: conversations of
  # other async tests would make it reload and compete for the connection
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Consulting.{Conversation, Conversations}
  alias Mercator.Consulting.Workers.SendCallbackRequest
  alias Mercator.Sales.Baskets
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
    assert_push_event(view, "desk:availability", %{available: true})
  end

  test "coming from the sign-in, the consultant is available at once",
       %{conn: conn, consultant: consultant} do
    {:ok, view, _html} = live(conn, ~p"/admin/desk?available=true")

    assert has_element?(view, "#availability", "Verfügbar")
    assert %{metas: [%{available: true}]} = Presence.get_by_key(Presence.topic(), consultant.id)
    assert_push_event(view, "desk:availability", %{available: true})

    # and can go away
    view |> element("#availability") |> render_click()
    assert has_element?(view, "#availability", "Abwesend")
  end

  test "a reloaded desk restores the tab's availability", %{conn: conn, consultant: consultant} do
    {:ok, view, _html} = live(conn, ~p"/admin/desk")
    assert has_element?(view, "#availability", "Abwesend")

    render_hook(view, "restore_availability", %{"available" => true})
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
    # a fresh, empty input after sending
    assert has_element?(chat, "#chat-input-1")
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
    assert has_element?(desk, "#reply-input-1")

    chat |> form("#chat-form", chat: %{body: "40 m²"}) |> render_submit()
    assert has_element?(chat, "#chat-input-2")
    assert has_element?(desk, "#desk-messages .chat-start", "40 m²")

    desk |> element("#close-conversation") |> render_click()
    refute has_element?(desk, "#desk-conversation-#{conversation.id}")
    assert Conversations.current(owner) == nil
  end

  test "answering takes the conversation; the customer stops waiting", %{conn: conn} do
    {customer_conn, owner} = visitor_conn()
    {:ok, conversation} = Conversations.start(owner, "Ist jemand da?")
    {:ok, chat, _html} = live_isolated(customer_conn, ChatLive)
    assert has_element?(chat, "#chat-waiting")

    {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
    desk |> form("#reply-form", reply: %{body: "Ja, gerne!"}) |> render_submit()

    assert has_element?(desk, "#mine-list #desk-conversation-#{conversation.id}")
    refute has_element?(desk, "#take")
    assert has_element?(chat, "#chat-status", "Sepp Fuchs")
    refute has_element?(chat, "#chat-waiting")
    assert has_element?(chat, "#chat-messages", "Ja, gerne!")
  end

  test "callback requests are marked on the desk", %{conn: conn} do
    {_customer_conn, owner} = visitor_conn()
    {:ok, conversation} = Conversations.start(owner, "Bitte zurückrufen")
    {:ok, _} = Conversations.request_callback(owner, conversation.id, :phone, "+43 1 2345678")

    {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
    assert has_element?(desk, "#desk-conversation-#{conversation.id} .badge", "Rückruf")
    assert has_element?(desk, "#conversation-callback", "+43 1 2345678")
  end

  test "a reply by email is not called a callback", %{conn: conn} do
    {_customer_conn, owner} = visitor_conn()
    {:ok, conversation} = Conversations.start(owner, "Bitte per Mail")
    {:ok, _} = Conversations.request_callback(owner, conversation.id, :email, "eva@example.com")

    {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")

    assert has_element?(
             desk,
             "#desk-conversation-#{conversation.id} .badge",
             "Antwort per E-Mail"
           )

    assert has_element?(desk, "#conversation-callback", "Antwort per E-Mail gewünscht")

    conversation =
      Ash.get!(Conversation, conversation.id,
        load: [:customer, :messages],
        authorize?: false
      )

    email = SendCallbackRequest.email(conversation)
    assert email.subject == "Antwort per E-Mail gewünscht: eva@example.com"
  end

  describe "customer context (step 3)" do
    test "online status, the page the customer is on, and the basket", %{conn: conn} do
      {customer_conn, {:session, token} = owner} = visitor_conn()
      product = product_fixture(title: %{"de" => "Lärchendiele"})
      [variant] = Ash.load!(product, :variants).variants
      Baskets.add({:session, token}, variant.id, 3)

      {:ok, conversation} =
        Conversations.start(owner, "Frage zur Terrasse", %{page: "/products/x"})

      {:ok, chat, _html} = live_isolated(customer_conn, ChatLive)

      {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
      assert has_element?(desk, ~s(#customer-online[data-online="true"]))
      assert has_element?(desk, "#customer-page", "/products/x")
      assert has_element?(desk, "#customer-basket", "Lärchendiele")

      # the customer moves on; the desk follows live
      render_hook(chat, "location", %{"path" => "/categories/terrasse"})
      assert has_element?(desk, "#customer-page", "/categories/terrasse")

      # the customer leaves the shop (Presence reports it asynchronously)
      Phoenix.PubSub.subscribe(Mercator.PubSub, Presence.chat_topic())
      GenServer.stop(chat.pid)

      assert_receive %Phoenix.Socket.Broadcast{event: "presence_diff", payload: %{leaves: leaves}}
                     when is_map_key(leaves, conversation.id)

      _ = render(desk)
      assert has_element?(desk, ~s(#customer-online[data-online="false"]))
    end

    test "the basket updates live while the conversation is open", %{conn: conn} do
      {_customer_conn, {:session, token} = owner} = visitor_conn()
      {:ok, conversation} = Conversations.start(owner, "Hallo")
      {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
      assert has_element?(desk, "#customer-basket", "Leer.")

      [variant] = Ash.load!(product_fixture(title: %{"de" => "Zirbenbrett"}), :variants).variants
      Baskets.add({:session, token}, variant.id, 2)

      assert has_element?(desk, "#customer-basket", "Zirbenbrett")

      # another customer's basket does not concern this conversation
      Baskets.add({:session, "someone-else"}, variant.id, 1)
      assert has_element?(desk, "#customer-basket", "Zirbenbrett")
    end

    test "previous orders of a signed-in customer", %{conn: conn} do
      import Mercator.SalesFixtures

      gtc_fixture()
      customer = customer_fixture()
      [variant] = Ash.load!(product_fixture(), :variants).variants
      order = order_fixture(customer, variant)

      {:ok, conversation} = Conversations.start({:user, customer}, "Nachbestellung?")
      {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")

      assert has_element?(desk, ~s(#customer-orders a[href="/admin/orders/#{order.number}"]))
    end
  end

  describe "sharing (step 3, #96)" do
    setup %{conn: conn, consultant: consultant} do
      {customer_conn, owner} = visitor_conn()
      {:ok, conversation} = Conversations.start(owner, "Was passt zu meiner Terrasse?")
      {:ok, chat, _html} = live_isolated(customer_conn, ChatLive)
      {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
      desk |> element("#take") |> render_click()
      %{chat: chat, desk: desk, consultant: consultant}
    end

    test "a recommended product appears as a card in the customer's chat", %{
      chat: chat,
      desk: desk
    } do
      product = product_fixture(title: %{"de" => "Terrassenöl Lärche"}, number: "OEL-1")

      desk |> element("#share-product") |> render_click()
      desk |> form("#share-search", %{"q" => "OEL-1"}) |> render_change()
      desk |> element("#recommend-#{product.id}") |> render_click()
      refute has_element?(desk, "#share-modal")

      assert has_element?(
               chat,
               ~s(#chat-messages a[href="/products/#{product.slug}"]),
               "Terrassenöl Lärche"
             )

      # on the desk the card opens a new tab
      assert has_element?(
               desk,
               ~s(#desk-messages a[target="_blank"][href="/products/#{product.slug}"])
             )
    end

    test "links: shop pages and websites, nothing else", %{chat: chat, desk: desk} do
      desk |> element("#share-link") |> render_click()
      desk |> form("#share-link-form", %{"url" => "javascript:alert(1)"}) |> render_submit()
      assert has_element?(desk, "#share-error")

      desk
      |> form("#share-link-form", %{"url" => "/pages/faq", "title" => "Häufige Fragen"})
      |> render_submit()

      assert has_element?(chat, ~s(#chat-messages a[href="/pages/faq"]), "Häufige Fragen")

      desk |> element("#share-link") |> render_click()

      desk
      |> form("#share-link-form", %{"url" => "https://example.com/anleitung.html"})
      |> render_submit()

      assert has_element?(
               chat,
               ~s(#chat-messages a[target="_blank"][rel="noopener noreferrer"][href="https://example.com/anleitung.html"])
             )
    end

    test "a file from the consultant's computer, not in the media library", %{
      chat: chat,
      desk: desk
    } do
      desk |> element("#share-upload") |> render_click()

      desk
      |> file_input("#upload-form", :chat_file, [
        %{
          name: "Verlegeplan Terrasse.pdf",
          content: File.read!("test/fixtures/sample.pdf"),
          type: "application/pdf"
        }
      ])
      |> render_upload("Verlegeplan Terrasse.pdf")

      desk |> form("#upload-form") |> render_submit()
      refute has_element?(desk, "#share-modal")

      assert has_element?(chat, "#chat-messages a[href$='.pdf']", "Verlegeplan Terrasse")
      assert Mercator.Content.search_assets!(%{query: "Verlegeplan"}) == []
    end

    test "files of the media library", %{chat: chat, desk: desk} do
      pdf =
        Mercator.Content.upload_asset!(
          %{
            source_path: "test/fixtures/sample.pdf",
            original_filename: "Pflegeanleitung.pdf",
            tags: ["pflege"],
            title: %{"de" => "Pflegeanleitung"}
          },
          actor: user_fixture(roles: [:contentmanager])
        )

      desk |> element("#share-file") |> render_click()
      desk |> form("#share-search", %{"q" => "pflege"}) |> render_change()
      desk |> element("#share-file-#{pdf.id}") |> render_click()

      assert has_element?(
               chat,
               ~s(#chat-messages a[href="/uploads/assets/#{pdf.id}/pflegeanleitung.pdf"]),
               "Pflegeanleitung"
             )
    end
  end
end
