defmodule Mercator.Seeds do
  @moduledoc """
  Demo and development data, loaded by `priv/repo/seeds.exs`.

  Seeding is idempotent: users that already exist (matched by email) are not
  created again, only their demo name is brought up to date, so
  `mix run priv/repo/seeds.exs` can run any number of times.

  All demo users share the password `demo_password/0` and are confirmed.
  """

  alias Mercator.Accounts.User

  require Ash.Query

  @demo_password "mercator-demo"

  # Surnames of animals living in the woods (Biber Holz demo)
  @demo_users [
    %{email: "admin@example.com", name: "Anna Specht", roles: [:administrator]},
    %{email: "sales@example.com", name: "Sepp Fuchs", roles: [:sales]},
    %{email: "manager@example.com", name: "Maria Hirsch", roles: [:sales, :sales_manager]},
    %{email: "content@example.com", name: "Klara Eichhorn", roles: [:contentmanager]},
    %{email: "products@example.com", name: "Peter Dachs", roles: [:productmanager]},
    %{email: "kunde@example.com", name: "Karl Luchs", roles: [], locale: :de},
    %{email: "customer@example.com", name: "Lena Igel", roles: [], locale: :en}
  ]

  @doc "The password of all demo users."
  def demo_password, do: @demo_password

  @doc "The demo users as attribute maps."
  def demo_users, do: @demo_users

  @doc "Seeds all demo data. Returns the demo users."
  def run do
    Enum.map(@demo_users, &ensure_user/1)
  end

  defp ensure_user(%{email: email} = attrs) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> create_user(attrs)
      %{name: name} = user when name == attrs.name -> user
      user -> Ash.Seed.update!(user, %{name: attrs.name})
    end
  end

  # Seeds bypass the registration action (no confirmation email, no token)
  # and write confirmed users directly.
  defp create_user(attrs) do
    Ash.Seed.seed!(
      User,
      Map.merge(
        %{
          hashed_password: Bcrypt.hash_pwd_salt(@demo_password),
          confirmed_at: DateTime.utc_now(),
          locale: :de
        },
        attrs
      )
    )
  end
end
