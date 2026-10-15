defmodule Mercator.Accounts.AuthEmailFailureTest do
  # switches the mailer adapter globally
  use Mercator.DataCase, async: false

  @moduletag :capture_log

  import Mercator.AccountsFixtures

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.Accounts.User
  alias Mercator.Operations.Incident

  # #120: sign-in emails are sent directly; a failure is reported, not raised
  setup do
    previous = Application.get_env(:mercator, Mercator.Mailer)
    Application.put_env(:mercator, Mercator.Mailer, adapter: Mercator.FailingMailAdapter)
    on_exit(fn -> Application.put_env(:mercator, Mercator.Mailer, previous) end)
  end

  defp incidents, do: Ash.read!(Incident, authorize?: false)

  test "registration succeeds and the failed confirmation email becomes an incident" do
    user = user_fixture(email: "nomail@example.com")

    assert [incident] = incidents()
    assert incident.kind == :email
    assert incident.customer_id == user.id
    assert incident.description =~ "nomail@example.com"
  end

  test "a failed password reset email becomes an incident" do
    user = user_fixture()
    strategy = Info.strategy!(User, :password)

    assert :ok = Strategy.action(strategy, :reset_request, %{"email" => to_string(user.email)})

    assert length(incidents()) == 2
  end

  test "a failed sign-in link email becomes an incident" do
    strategy = Info.strategy!(User, :magic_link)

    assert :ok = Strategy.action(strategy, :request, %{"email" => "new@example.com"})

    assert [incident] = incidents()
    assert incident.customer_id == nil
  end
end
