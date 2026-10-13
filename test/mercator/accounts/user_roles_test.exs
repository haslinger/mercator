defmodule Mercator.Accounts.UserRolesTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.Accounts
  alias Mercator.Accounts.User

  describe "roles" do
    test "new users have no roles" do
      assert user_fixture().roles == []
    end

    test "registration rejects a roles parameter" do
      assert {:error, %Ash.Error.Invalid{}} =
               Strategy.action(Info.strategy!(User, :password), :register, %{
                 "email" => unique_email(),
                 "password" => valid_password(),
                 "password_confirmation" => valid_password(),
                 "roles" => ["administrator"]
               })
    end

    test "an administrator can set roles" do
      admin = user_fixture(roles: [:administrator])
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.set_user_roles(user, [:sales, :contentmanager], actor: admin)

      assert Enum.sort(updated.roles) == [:contentmanager, :sales]
    end

    test "non-administrators cannot set roles, not even their own" do
      sales = user_fixture(roles: [:sales])
      user = user_fixture()

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.set_user_roles(user, [:sales], actor: sales)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.set_user_roles(sales, [:administrator], actor: sales)
    end

    test "unknown roles are rejected" do
      admin = user_fixture(roles: [:administrator])

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.set_user_roles(user_fixture(), [:superuser], actor: admin)
    end
  end

  describe "read policy" do
    test "a user only sees themselves" do
      user = user_fixture()
      other = user_fixture()

      assert [%{id: id}] = Accounts.list_users!(actor: user)
      assert id == user.id
      assert {:error, _} = Accounts.get_user(other.id, actor: user)
    end

    test "an administrator sees all users" do
      admin = user_fixture(roles: [:administrator])
      _others = [user_fixture(), user_fixture()]

      assert length(Accounts.list_users!(actor: admin)) == 3
    end

    test "staff roles other than administrator grant no access to other users" do
      sales = user_fixture(roles: [:sales, :sales_manager, :contentmanager, :productmanager])
      _other = user_fixture()

      assert [%{id: id}] = Accounts.list_users!(actor: sales)
      assert id == sales.id
    end

    test "anonymous visitors see no users" do
      _user = user_fixture()

      assert Accounts.list_users!() == []
    end
  end

  describe "change_password policy" do
    defp change_password(user, actor) do
      user
      |> Ash.Changeset.for_update(
        :change_password,
        %{
          current_password: valid_password(),
          password: "a new password 123",
          password_confirmation: "a new password 123"
        },
        actor: actor
      )
      |> Ash.update()
    end

    test "a user can change their own password" do
      user = user_fixture()

      assert {:ok, _} = change_password(user, user)
    end

    test "a user cannot change another user's password" do
      user = user_fixture()

      assert {:error, %Ash.Error.Forbidden{}} = change_password(user, user_fixture())
    end
  end
end
