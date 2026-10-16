defmodule Mercator.Consulting.PhoneNotificationsTest do
  # Req.Test stubs and Oban jobs belong to the test process; Presence keys
  # are the test's own users
  use Mercator.DataCase, async: true
  use Oban.Testing, repo: Mercator.Repo

  import Mercator.AccountsFixtures

  alias Mercator.Consulting.{Conversations, Desk, PhoneNotifications}
  alias Mercator.Consulting.Workers.SendPhoneNotification
  alias Mercator.{FakePushDevice, WebPush}
  alias MercatorWeb.Presence

  defp visitor, do: {:session, "token-#{System.unique_integer([:positive])}"}

  defp endpoint, do: "https://push.example.com/send/#{System.unique_integer([:positive])}"

  # a device of `user` with notifications on
  defp device(user) do
    device = FakePushDevice.new()
    endpoint = endpoint()
    {:ok, _} = PhoneNotifications.subscribe(user, FakePushDevice.subscription(device, endpoint))
    Map.put(device, :endpoint, endpoint)
  end

  # the push service: every notification reaches the test, decrypted by its device
  defp stub_push_service(devices, status \\ 201) do
    test = self()
    by_path = Map.new(devices, &{URI.parse(&1.endpoint).path, &1})

    Req.Test.stub(WebPush, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      device = Map.fetch!(by_path, conn.request_path)

      send(
        test,
        {:push, device.endpoint, device |> FakePushDevice.decrypt(body) |> Jason.decode!()}
      )

      Plug.Conn.send_resp(conn, status, "")
    end)
  end

  describe "subscribing" do
    test "sales staff switch a device on and off" do
      consultant = user_fixture(roles: [:sales])
      device = device(consultant)

      assert [%{endpoint: endpoint}] =
               Mercator.Accounts.list_my_push_subscriptions!(actor: consultant)

      assert endpoint == device.endpoint

      :ok = PhoneNotifications.unsubscribe(consultant, device.endpoint)
      assert Mercator.Accounts.list_my_push_subscriptions!(actor: consultant) == []
    end

    test "customers cannot" do
      params = FakePushDevice.subscription(FakePushDevice.new(), endpoint())

      assert {:error, %Ash.Error.Forbidden{}} =
               PhoneNotifications.subscribe(user_fixture(), params)
    end

    test "a device someone else signs in on moves to them" do
      first = user_fixture(roles: [:sales])
      second = user_fixture(roles: [:sales_manager])
      params = FakePushDevice.subscription(FakePushDevice.new(), endpoint())

      {:ok, _} = PhoneNotifications.subscribe(first, params)
      {:ok, _} = PhoneNotifications.subscribe(second, params)

      assert Mercator.Accounts.list_my_push_subscriptions!(actor: first) == []
      assert [_] = Mercator.Accounts.list_my_push_subscriptions!(actor: second)
    end

    test "nobody switches off someone else's device" do
      consultant = user_fixture(roles: [:sales])
      device = device(consultant)

      :ok = PhoneNotifications.unsubscribe(user_fixture(roles: [:sales]), device.endpoint)
      assert [_] = Mercator.Accounts.list_my_push_subscriptions!(actor: consultant)
    end
  end

  describe "a new conversation" do
    test "notifies all staff with notifications on, at the same time (#153)" do
      sepp = device(user_fixture(roles: [:sales]))
      maria = device(user_fixture(roles: [:sales_manager]))

      # a former consultant's device stays quiet
      former = user_fixture(roles: [:sales])
      quiet = device(former)
      Mercator.Accounts.set_user_roles!(former, [], authorize?: false)

      {:ok, conversation} = Conversations.start(visitor(), "Wie viel Lärche brauche ich?")

      args = %{event: "new_conversation", conversation_id: conversation.id}
      assert_enqueued worker: SendPhoneNotification, args: args

      stub_push_service([sepp, maria, quiet])
      assert :ok = perform_job(SendPhoneNotification, args)

      url = "/admin/desk/#{conversation.id}"

      for device <- [sepp, maria] do
        assert_received {:push, endpoint,
                         %{"title" => "Neues Gespräch", "body" => body, "url" => ^url}}
                        when endpoint == device.endpoint

        assert body == "Gast: Wie viel Lärche brauche ich?"
      end

      refute_received {:push, _, _}
    end

    test "is not sent once a consultant has taken it" do
      consultant = user_fixture(roles: [:sales])
      device = device(consultant)
      {:ok, conversation} = Conversations.start(visitor(), "Hallo")
      {:ok, _} = Desk.take(conversation, consultant)

      stub_push_service([device])

      assert :ok =
               perform_job(SendPhoneNotification, %{
                 event: "new_conversation",
                 conversation_id: conversation.id
               })

      refute_received {:push, _, _}
    end

    test "in the staff member's language" do
      lena = user_fixture(roles: [:sales]) |> Ash.Seed.update!(%{locale: :en})
      device = device(lena)
      {:ok, conversation} = Conversations.start(visitor(), "Hello")

      stub_push_service([device])

      perform_job(SendPhoneNotification, %{
        event: "new_conversation",
        conversation_id: conversation.id
      })

      assert_received {:push, _, %{"title" => "New conversation", "body" => "Visitor: Hello"}}
    end
  end

  describe "a customer's message" do
    setup do
      consultant = user_fixture(roles: [:sales])
      colleague = device(user_fixture(roles: [:sales]))
      owner = visitor()
      {:ok, conversation} = Conversations.start(owner, "Hallo")
      {:ok, _} = Desk.take(conversation, consultant)

      %{consultant: consultant, colleague: colleague, owner: owner, conversation: conversation}
    end

    test "notifies only the conversation's consultant", ctx do
      device = device(ctx.consultant)
      {:ok, message} = Conversations.post(ctx.owner, ctx.conversation.id, "Und die Schrauben?")

      args = %{event: "message", message_id: message.id}
      assert_enqueued worker: SendPhoneNotification, args: args

      stub_push_service([device, ctx.colleague])
      perform_job(SendPhoneNotification, args)

      url = "/admin/desk/#{ctx.conversation.id}"
      tag = "conversation-#{ctx.conversation.id}"
      endpoint = device.endpoint

      assert_received {:push, ^endpoint,
                       %{
                         "title" => "Nachricht von Gast",
                         "body" => "Und die Schrauben?",
                         "url" => ^url,
                         "tag" => ^tag
                       }}

      refute_received {:push, _, _}
    end

    test "not while the consultant has the conversation open at the desk", ctx do
      {:ok, _} =
        Presence.track(self(), Presence.topic(), ctx.consultant.id, %{
          available: true,
          name: "Sepp",
          conversation_id: ctx.conversation.id
        })

      {:ok, _} = Conversations.post(ctx.owner, ctx.conversation.id, "Und die Schrauben?")

      refute_enqueued worker: SendPhoneNotification, args: %{event: "message"}
    end

    test "a device that is gone is deleted", ctx do
      device = device(ctx.consultant)
      {:ok, message} = Conversations.post(ctx.owner, ctx.conversation.id, "Hallo?")

      stub_push_service([device], 410)
      assert :ok = perform_job(SendPhoneNotification, %{event: "message", message_id: message.id})

      assert Mercator.Accounts.list_my_push_subscriptions!(actor: ctx.consultant) == []
    end
  end

  test "a test notification reaches only the one device" do
    consultant = user_fixture(roles: [:sales])
    [one, other] = [device(consultant), device(consultant)]

    :ok = PhoneNotifications.test(consultant, one.endpoint)
    args = %{event: "test", user_id: consultant.id, endpoint: one.endpoint}
    assert_enqueued worker: SendPhoneNotification, args: args

    stub_push_service([one, other])
    perform_job(SendPhoneNotification, args)

    endpoint = one.endpoint
    assert_received {:push, ^endpoint, %{"title" => "Benachrichtigungen sind an"}}
    refute_received {:push, _, _}
  end
end
