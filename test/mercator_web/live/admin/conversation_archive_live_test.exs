defmodule MercatorWeb.Admin.ConversationArchiveLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Consulting.{Conversations, Desk}

  setup %{conn: conn} do
    consultant = user_fixture(roles: [:sales]) |> Ash.Seed.update!(%{name: "Sepp Fuchs"})
    customer = user_fixture() |> Ash.Seed.update!(%{name: "Karla Dachs"})
    %{conn: log_in_user(conn, consultant), consultant: consultant, customer: customer}
  end

  defp closed(owner, subject, consultant) do
    {:ok, conversation} = Conversations.start(owner, "Frage zu #{subject}", %{subject: subject})
    {:ok, conversation} = Desk.take(conversation, consultant)
    {:ok, conversation} = Desk.close(conversation, consultant)
    conversation
  end

  test "only sales staff and administrators" do
    conn = log_in_user(build_conn(), user_fixture())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/conversations")
  end

  test "closed conversations: search by customer or subject, only mine",
       %{conn: conn} = context do
    mine = closed({:user, context.customer}, "Archivterrasse", context.consultant)
    other = closed({:session, "archive-visitor"}, "Archivzaun", user_fixture(roles: [:sales]))
    {:ok, open} = Conversations.start({:session, "archive-open"}, "Noch offen")

    {:ok, view, _html} = live(conn, ~p"/admin/conversations")
    assert has_element?(view, "#conversations a[href='/admin/desk/#{mine.id}']")
    assert has_element?(view, "#conversations a[href='/admin/desk/#{other.id}']")
    refute has_element?(view, "#conversations a[href='/admin/desk/#{open.id}']")

    view |> form("#archive-filters", %{"q" => "Karla Dachs"}) |> render_change()
    assert has_element?(view, "#conversations a[href='/admin/desk/#{mine.id}']")
    refute has_element?(view, "#conversations a[href='/admin/desk/#{other.id}']")

    view |> form("#archive-filters", %{"q" => "archivzaun"}) |> render_change()
    assert has_element?(view, "#conversations a[href='/admin/desk/#{other.id}']")
    refute has_element?(view, "#conversations a[href='/admin/desk/#{mine.id}']")

    {:ok, _} = Conversations.rate({:user, context.customer}, mine.id, 5, "Top Beratung")
    {:ok, view, _html} = live(conn, ~p"/admin/conversations")
    assert has_element?(view, "#conversations", "Top Beratung")

    view |> form("#archive-filters", %{"q" => "", "mine" => "true"}) |> render_change()
    assert has_element?(view, "#conversations a[href='/admin/desk/#{mine.id}']")
    refute has_element?(view, "#conversations a[href='/admin/desk/#{other.id}']")
  end

  test "a closed conversation reads on the desk; earlier ones are listed",
       %{conn: conn} = context do
    earlier = closed({:user, context.customer}, "Gartenhaus", context.consultant)
    {:ok, current} = Conversations.start({:user, context.customer}, "Wieder ich")

    {:ok, desk, _html} = live(conn, ~p"/admin/desk/#{current.id}")
    assert has_element?(desk, "#customer-earlier #earlier-#{earlier.id}")

    desk |> element("#earlier-#{earlier.id}") |> render_click()
    assert_patch(desk, ~p"/admin/desk/#{earlier.id}")
    assert has_element?(desk, "#conversation-closed")
    assert has_element?(desk, "#desk-messages", "Frage zu Gartenhaus")
    assert has_element?(desk, "#conversation-ended")
    refute has_element?(desk, "#reply-form")
    refute has_element?(desk, "#take")
    refute has_element?(desk, "#close-conversation")
  end
end
