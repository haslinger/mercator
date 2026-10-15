defmodule Mercator.Accounts.RateLimitTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.Accounts.User
  alias Mercator.Operations.Incident

  defp sign_in(email, password, ip \\ nil) do
    Strategy.action(
      Info.strategy!(User, :password),
      :sign_in,
      %{"email" => email, "password" => password},
      context: %{client_ip: ip}
    )
  end

  # distinct per test: the per-IP counters are shared by async tests
  defp unique_ip, do: "203.0.113.#{System.unique_integer([:positive])}"

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

  describe "per client IP (#126)" do
    test "a bot guessing passwords does not lock out the account's owner" do
      user = user_fixture()
      email = to_string(user.email)
      bot = unique_ip()

      for _ <- 1..10, do: assert({:error, _} = sign_in(email, "wrong password", bot))

      assert {:error, _} = sign_in(email, valid_password(), bot)
      assert {:ok, _} = sign_in(email, valid_password(), unique_ip())
    end

    test "one IP cannot try more than 30 sign-ins, whatever the addresses" do
      bot = unique_ip()

      for _ <- 1..30, do: assert({:error, _} = sign_in(unique_email(), "wrong password", bot))

      user = user_fixture()
      assert {:error, _} = sign_in(to_string(user.email), valid_password(), bot)
    end

    test "a reached limit is one incident per IP that counts up" do
      user = user_fixture()
      email = to_string(user.email)
      bot = unique_ip()

      for _ <- 1..12, do: sign_in(email, "wrong password", bot)

      assert [incident] =
               Incident
               |> Ash.read!(authorize?: false)
               |> Enum.filter(&String.contains?(&1.title, bot))

      assert incident.kind == :other
      assert incident.occurrences == 2
    end

    test "at most 10 auth emails per address, from all IPs together" do
      user = user_fixture()
      strategy = Info.strategy!(User, :password)
      params = %{"email" => to_string(user.email)}

      for _ <- 1..10 do
        assert :ok =
                 Strategy.action(strategy, :reset_request, params,
                   context: %{client_ip: unique_ip()}
                 )
      end

      assert {:error, _} =
               Strategy.action(strategy, :reset_request, params,
                 context: %{client_ip: unique_ip()}
               )
    end
  end
end
