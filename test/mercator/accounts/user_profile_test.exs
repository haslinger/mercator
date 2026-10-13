defmodule Mercator.Accounts.UserProfileTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Accounts

  test "new users have no name or phone and German as language" do
    user = user_fixture()

    assert is_nil(user.name)
    assert is_nil(user.phone)
    assert user.locale == :de
  end

  test "a user can update their own profile" do
    user = user_fixture()

    assert {:ok, updated} =
             Accounts.update_profile(
               user,
               %{name: "Maria Huber", phone: "+43 1 234 56 78", locale: :en},
               actor: user
             )

    assert updated.name == "Maria Huber"
    assert updated.phone == "+43 1 234 56 78"
    assert updated.locale == :en
  end

  test "unsupported languages are rejected" do
    user = user_fixture()

    assert {:error, %Ash.Error.Invalid{}} =
             Accounts.update_profile(user, %{locale: :fr}, actor: user)
  end

  test "the profile update cannot change roles" do
    user = user_fixture()

    assert {:error, %Ash.Error.Invalid{}} =
             Accounts.update_profile(user, %{roles: [:administrator]}, actor: user)
  end

  test "a user cannot update someone else's profile" do
    user = user_fixture()

    assert {:error, %Ash.Error.Forbidden{}} =
             Accounts.update_profile(user, %{name: "Hacked"}, actor: user_fixture())
  end

  test "an administrator can update any profile" do
    admin = user_fixture(roles: [:administrator])

    assert {:ok, %{name: "Maria Huber"}} =
             Accounts.update_profile(user_fixture(), %{name: "Maria Huber"}, actor: admin)
  end
end
