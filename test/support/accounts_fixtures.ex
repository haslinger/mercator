defmodule Mercator.AccountsFixtures do
  @moduledoc """
  Test helpers for creating users.
  """

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.Accounts.User

  @password "correct horse battery"

  def valid_password, do: @password

  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc "Registers a user via the password strategy, optionally with staff roles."
  def user_fixture(opts \\ []) do
    {:ok, user} =
      Strategy.action(Info.strategy!(User, :password), :register, %{
        "email" => Keyword.get(opts, :email, unique_email()),
        "password" => @password,
        "password_confirmation" => @password
      })

    case Keyword.get(opts, :roles, []) do
      [] -> user
      roles -> Mercator.Accounts.set_user_roles!(user, roles, authorize?: false)
    end
  end
end
