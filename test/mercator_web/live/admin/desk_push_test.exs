defmodule MercatorWeb.Admin.DeskPushTest do
  # phone notifications at the desk (#151); the desk follows the global
  # "desk" topic and Presence, like MercatorWeb.Admin.DeskLiveTest
  use MercatorWeb.ConnCase, async: false
  use Oban.Testing, repo: Mercator.Repo

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Consulting.Conversations
  alias Mercator.Consulting.Workers.SendPhoneNotification
  alias Mercator.FakePushDevice
  alias MercatorWeb.Presence

  setup %{conn: conn} do
    consultant = user_fixture(roles: [:sales])
    %{conn: log_in_user(conn, consultant), consultant: consultant}
  end

  defp subscription,
    do:
      FakePushDevice.subscription(
        FakePushDevice.new(),
        "https://push.example.com/send/#{System.unique_integer([:positive])}"
      )

  test "the switch waits for the browser's answer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/desk")

    assert has_element?(view, "#push-switch[data-key]")
    assert has_element?(view, "#push-toggle[disabled]")

    render_hook(view, "push:status", %{"status" => "off"})
    refute has_element?(view, "#push-toggle[disabled]")
    refute has_element?(view, "#push-test")
  end

  test "switching on and off, with a test notification", %{conn: conn, consultant: consultant} do
    {:ok, view, _html} = live(conn, ~p"/admin/desk")
    params = subscription()

    render_hook(view, "push:subscribe", params)
    assert has_element?(view, "#push-toggle.btn-success")
    assert [_] = Mercator.Accounts.list_my_push_subscriptions!(actor: consultant)

    view |> element("#push-test") |> render_click()

    assert_enqueued worker: SendPhoneNotification,
                    args: %{event: "test", user_id: consultant.id, endpoint: params["endpoint"]}

    render_hook(view, "push:unsubscribe", %{"endpoint" => params["endpoint"]})
    refute has_element?(view, "#push-toggle.btn-success")
    assert Mercator.Accounts.list_my_push_subscriptions!(actor: consultant) == []
  end

  test "blocked or unsupported in the browser", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/desk")

    render_hook(view, "push:status", %{"status" => "denied"})
    assert has_element?(view, "#push-toggle[disabled]")

    render_hook(view, "push:status", %{"status" => "unsupported"})
    refute has_element?(view, "#push-switch")
  end

  test "Presence knows which conversation is open", %{conn: conn, consultant: consultant} do
    {:ok, conversation} =
      Conversations.start({:session, "push-#{System.unique_integer([:positive])}"}, "Hallo")

    {:ok, view, _html} = live(conn, ~p"/admin/desk/#{conversation.id}")
    assert Presence.viewing?(consultant.id, conversation.id)

    view |> element("#availability") |> render_click()
    assert Presence.viewing?(consultant.id, conversation.id)

    render_patch(view, ~p"/admin/desk")
    refute Presence.viewing?(consultant.id, conversation.id)
  end

  test "pages tell the browser whether someone is signed in (unsubscribing at sign-out)",
       %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200) =~ ~s(data-signed-in="true")
    assert build_conn() |> get(~p"/") |> html_response(200) =~ ~s(data-signed-in="false")
  end
end
