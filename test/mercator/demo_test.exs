defmodule Mercator.DemoTest do
  # demo mode is a global switch, and the reset empties all tables
  use Mercator.DataCase, async: false
  use Oban.Testing, repo: Mercator.Repo

  import Mercator.AccountsFixtures

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.{Accounts, Demo, Payments, Seeds}
  alias Mercator.Accounts.User
  alias Mercator.Demo.Workers.Reset
  alias Mercator.Payments.Simulator

  require Ash.Query

  defp demo_mode(_context) do
    Application.put_env(:mercator, :demo_mode, true)
    Application.put_env(:mercator, :demo_admin_password, "secret admin password")

    on_exit(fn ->
      Application.delete_env(:mercator, :demo_mode)
      Application.delete_env(:mercator, :demo_admin_password)
    end)
  end

  defp sign_in(email, password) do
    Strategy.action(Info.strategy!(User, :password), :sign_in, %{
      "email" => email,
      "password" => password
    })
  end

  defp user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  describe "outside demo mode" do
    test "is off and protects nothing" do
      refute Demo.enabled?()
      refute Demo.public_account?("sales@mittenin.at")
    end

    test "the reset job does nothing" do
      user = user_fixture()

      assert :ok = perform_job(Reset, %{})
      assert user(to_string(user.email))
    end
  end

  describe "in demo mode" do
    setup :demo_mode

    test "the public accounts are all demo users but the administrator" do
      emails = Enum.map(Demo.public_logins(), & &1.email)

      assert "sales@mittenin.at" in emails
      assert "kunde@mittenin.at" in emails
      refute "admin@mittenin.at" in emails
      assert Demo.public_account?("Sales@Mittenin.at")
      refute Demo.public_account?("admin@mittenin.at")
      refute Demo.public_account?("someone@example.com")
    end

    test "seeding gives the administrator the secret password and activates the simulator" do
      Demo.seed()

      assert {:ok, _} = sign_in("admin@mittenin.at", "secret admin password")
      assert {:error, _} = sign_in("admin@mittenin.at", Demo.password())
      assert {:ok, _} = sign_in("sales@mittenin.at", Demo.password())
      assert Payments.active() == Simulator
    end

    test "seed_if_empty seeds an empty database only" do
      assert :ok = Demo.seed_if_empty()
      count = length(Ash.read!(User, authorize?: false))
      assert count == length(Seeds.demo_users())

      user_fixture()
      assert :ok = Demo.seed_if_empty()
      assert length(Ash.read!(User, authorize?: false)) == count + 1
    end

    test "public demo accounts cannot change their password" do
      Demo.seed()
      sales = user("sales@mittenin.at")

      assert {:error, %Ash.Error.Invalid{}} =
               sales
               |> Ash.Changeset.for_update(
                 :change_password,
                 %{
                   current_password: Demo.password(),
                   password: "a new password 123",
                   password_confirmation: "a new password 123"
                 },
                 actor: sales
               )
               |> Ash.update()

      assert {:ok, _} = sign_in("sales@mittenin.at", Demo.password())
    end

    test "other accounts can still change their password" do
      user = user_fixture()

      assert {:ok, _} =
               user
               |> Ash.Changeset.for_update(
                 :change_password,
                 %{
                   current_password: valid_password(),
                   password: "a new password 123",
                   password_confirmation: "a new password 123"
                 },
                 actor: user
               )
               |> Ash.update()
    end

    test "nobody can change the roles of a public demo account" do
      [admin | _] = Demo.seed()
      sales = user("sales@mittenin.at")

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.set_user_roles(sales, [:administrator], actor: admin)

      assert {:ok, _} = Accounts.set_user_roles(user_fixture(), [:sales], actor: admin)
    end

    test "public demo accounts cannot request a password reset" do
      Demo.seed()
      strategy = Info.strategy!(User, :password)

      assert {:error, _} =
               Strategy.action(strategy, :reset_request, %{"email" => "sales@mittenin.at"})

      assert :ok = Strategy.action(strategy, :reset_request, %{"email" => "admin@mittenin.at"})
    end

    test "the nightly reset empties everything and seeds again" do
      uploads =
        Path.join(System.tmp_dir!(), "mercator-demo-#{System.unique_integer([:positive])}")

      File.mkdir_p!(Path.join(uploads, "products"))
      File.write!(Path.join([uploads, "products", "photo.jpg"]), "jpg")
      previous = Application.fetch_env!(:mercator, :uploads_dir)
      Application.put_env(:mercator, :uploads_dir, uploads)

      on_exit(fn ->
        Application.put_env(:mercator, :uploads_dir, previous)
        File.rm_rf!(uploads)
      end)

      Demo.seed()
      visitor = user_fixture()
      sales = user("sales@mittenin.at")
      Ash.Seed.update!(sales, %{name: "Changed"})

      assert :ok = perform_job(Reset, %{})

      refute user(to_string(visitor.email))
      assert user("sales@mittenin.at").name == "Sepp Fuchs"
      assert length(Ash.read!(User, authorize?: false)) == length(Seeds.demo_users())
      assert File.ls!(uploads) == []
      assert Payments.active() == Simulator
    end
  end
end
