defmodule MercatorWeb.SignInRateLimitTest do
  # the sign-in page's client IP is always 127.0.0.1 in tests
  use MercatorWeb.ConnCase, async: false

  # reaching a limit logs a warning (#136)
  @moduletag :capture_log

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  @form "#user-password-sign-in-with-password"

  defp submit(view, email, password) do
    view
    |> form(@form, user: %{email: email, password: password})
    |> render_submit()
  end

  test "the sign-in page counts per address and client IP (#126)", %{conn: conn} do
    user = user_fixture()
    email = to_string(user.email)

    # attempts from elsewhere (other IPs, or without one) do not block this one
    for _ <- 1..10, do: Mercator.RateLimit.check(:sign_in, email)
    for _ <- 1..10, do: Mercator.RateLimit.check(:sign_in, "#{email}|198.51.100.9")

    {:ok, view, _html} = live(conn, ~p"/sign-in")
    # signed in: on to the token exchange
    assert {:error, {:redirect, _}} = submit(view, email, valid_password())

    # the same address from this IP is blocked after 10 attempts
    for _ <- 1..10, do: Mercator.RateLimit.check(:sign_in, "#{email}|127.0.0.1")

    {:ok, view, _html} = live(conn, ~p"/sign-in")
    assert is_binary(submit(view, email, valid_password()))
    assert has_element?(view, "#{@form} .text-error")
  end

  test "typing in the forms is not counted, only submitting", %{conn: conn} do
    user = user_fixture()
    email = to_string(user.email)
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    for password <- Enum.map(1..12, &String.duplicate("x", &1)) do
      view |> form(@form, user: %{email: email, password: password}) |> render_change()
    end

    for _ <- 1..5 do
      view
      |> form("#user-magic-link-request-magic-link", user: %{email: email})
      |> render_change()
    end

    assert {:allow, 1} = Mercator.RateLimit.hit("sign_in:#{email}|127.0.0.1", 900_000, 100)
    assert {:allow, 1} = Mercator.RateLimit.hit("auth_email:#{email}|127.0.0.1", 900_000, 100)
    assert {:error, {:redirect, _}} = submit(view, email, valid_password())
  end
end
