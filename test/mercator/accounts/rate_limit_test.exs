defmodule Mercator.Accounts.RateLimitTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.Accounts.User

  defp sign_in(email, password) do
    Strategy.action(Info.strategy!(User, :password), :sign_in, %{
      "email" => email,
      "password" => password
    })
  end

  test "after 10 failed sign-ins the address is blocked for a while (#87)" do
    user = user_fixture()
    email = to_string(user.email)

    for _ <- 1..10, do: assert({:error, _} = sign_in(email, "wrong password"))

    # even the right password is refused now; the message stays neutral
    assert {:error, error} = sign_in(email, valid_password())
    assert Exception.message(error) =~ "Authentication failed"

    # other addresses are not affected
    other = user_fixture()
    assert {:ok, _} = sign_in(to_string(other.email), valid_password())
  end

  test "at most 3 password reset emails per address" do
    user = user_fixture()
    strategy = Info.strategy!(User, :password)

    for _ <- 1..3 do
      assert :ok = Strategy.action(strategy, :reset_request, %{"email" => to_string(user.email)})
    end

    assert {:error, _} =
             Strategy.action(strategy, :reset_request, %{"email" => to_string(user.email)})
  end

  test "at most 3 magic links per address, also for unknown addresses" do
    strategy = Info.strategy!(User, :magic_link)
    email = unique_email()

    for _ <- 1..3, do: assert(:ok = Strategy.action(strategy, :request, %{"email" => email}))
    assert {:error, _} = Strategy.action(strategy, :request, %{"email" => email})
  end
end
