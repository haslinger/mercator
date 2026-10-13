defmodule Mercator.Accounts.UserAuthenticationTest do
  use Mercator.DataCase, async: true

  import Swoosh.TestAssertions

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.Accounts.User

  @password "correct horse battery"

  defp strategy(name), do: Info.strategy!(User, name)

  # Receives the next sent email and extracts the token following `path`.
  defp token_from_email(path) do
    receive do
      {:email, %Swoosh.Email{html_body: body}} ->
        [_, token] = Regex.run(~r{#{Regex.escape(path)}([^"<\s]+)}, body)
        token
    after
      1000 -> flunk("no email containing #{path} was sent")
    end
  end

  defp register(email \\ "kunde@example.com") do
    Strategy.action(strategy(:password), :register, %{
      "email" => email,
      "password" => @password,
      "password_confirmation" => @password
    })
  end

  describe "password strategy" do
    test "registers a user with a hashed password and sends a confirmation email" do
      assert {:ok, user} = register()

      assert to_string(user.email) == "kunde@example.com"
      assert user.hashed_password
      refute user.hashed_password == @password
      assert user.__metadata__.token
      assert is_nil(user.confirmed_at)

      assert_email_sent(fn email ->
        assert email.to == [{"", "kunde@example.com"}]
        assert email.from == Mercator.Mailer.default_from()
      end)
    end

    test "rejects a registration whose password confirmation does not match" do
      assert {:error, _} =
               Strategy.action(strategy(:password), :register, %{
                 "email" => "kunde@example.com",
                 "password" => @password,
                 "password_confirmation" => "something else"
               })
    end

    test "rejects passwords shorter than 8 characters" do
      assert {:error, _} =
               Strategy.action(strategy(:password), :register, %{
                 "email" => "kunde@example.com",
                 "password" => "short",
                 "password_confirmation" => "short"
               })
    end

    test "rejects a second registration with the same email, case-insensitively" do
      assert {:ok, _} = register("kunde@example.com")
      assert {:error, _} = register("KUNDE@example.com")
    end

    test "signs in with the correct password" do
      {:ok, user} = register()

      assert {:ok, signed_in} =
               Strategy.action(strategy(:password), :sign_in, %{
                 "email" => "kunde@example.com",
                 "password" => @password
               })

      assert signed_in.id == user.id
      assert signed_in.__metadata__.token
    end

    test "does not sign in with a wrong password" do
      {:ok, _user} = register()

      assert {:error, _} =
               Strategy.action(strategy(:password), :sign_in, %{
                 "email" => "kunde@example.com",
                 "password" => "wrong password"
               })
    end
  end

  describe "magic link strategy" do
    test "sends a login link to a new email address" do
      assert :ok =
               Strategy.action(strategy(:magic_link), :request, %{"email" => "neu@example.com"})

      assert_email_sent(fn email ->
        assert email.to == [{"", "neu@example.com"}]
        assert email.html_body =~ "/magic_link/"
      end)
    end

    test "registers and confirms a new user who signs in via magic link" do
      :ok = Strategy.action(strategy(:magic_link), :request, %{"email" => "neu@example.com"})
      token = token_from_email("/magic_link/")

      assert {:ok, user} = Strategy.action(strategy(:magic_link), :sign_in, %{"token" => token})
      assert to_string(user.email) == "neu@example.com"
      assert user.confirmed_at
    end

    test "refuses magic link sign-in for an unconfirmed password account" do
      # Protects against account takeover: someone could register another
      # person's address with their own password.
      {:ok, _user} = register()
      _confirmation_token = token_from_email("/confirm_new_user/")

      :ok = Strategy.action(strategy(:magic_link), :request, %{"email" => "kunde@example.com"})
      token = token_from_email("/magic_link/")

      assert {:error, _} = Strategy.action(strategy(:magic_link), :sign_in, %{"token" => token})
    end

    test "signs in a confirmed password account via magic link" do
      {:ok, user} = register()
      confirmation_token = token_from_email("/confirm_new_user/")

      assert {:ok, confirmed} =
               Strategy.action(Info.strategy!(User, :confirm_new_user), :confirm, %{
                 "confirm" => confirmation_token
               })

      assert confirmed.confirmed_at

      :ok = Strategy.action(strategy(:magic_link), :request, %{"email" => "kunde@example.com"})
      token = token_from_email("/magic_link/")

      assert {:ok, signed_in} =
               Strategy.action(strategy(:magic_link), :sign_in, %{"token" => token})

      assert signed_in.id == user.id
    end
  end

  describe "policies" do
    test "users cannot be read without going through authentication" do
      {:ok, _user} = register()

      assert {:error, %Ash.Error.Forbidden{}} = Ash.read(User)
    end
  end
end
