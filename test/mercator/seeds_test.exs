defmodule Mercator.SeedsTest do
  use Mercator.DataCase, async: false

  alias AshAuthentication.{Info, Strategy}
  alias Mercator.Accounts.User
  alias Mercator.Seeds

  test "creates confirmed demo users with their roles" do
    users = Seeds.run()

    assert length(users) == length(Seeds.demo_users())
    assert Enum.all?(users, & &1.confirmed_at)

    admin = Enum.find(users, &(to_string(&1.email) == "admin@example.com"))
    assert admin.roles == [:administrator]
  end

  test "creates the Austrian tax classes" do
    Seeds.run()

    assert {:ok, standard} = Mercator.Catalog.get_tax_class_by_key("standard")
    assert {:ok, reduced} = Mercator.Catalog.get_tax_class_by_key("reduced")
    assert Decimal.equal?(standard.rate, 20)
    assert Decimal.equal?(reduced.rate, 13)
  end

  test "is idempotent" do
    first = Seeds.run()
    second = Seeds.run()

    assert Enum.map(first, & &1.id) == Enum.map(second, & &1.id)
    assert length(Ash.read!(User, authorize?: false)) == length(Seeds.demo_users())
  end

  test "brings the names of existing demo users up to date" do
    [admin | _] = Seeds.run()
    Ash.Seed.update!(admin, %{name: "Old Name"})

    [admin | _] = Seeds.run()

    assert admin.name == "Anna Specht"
  end

  test "demo users can sign in with the demo password" do
    Seeds.run()

    assert {:ok, user} =
             Strategy.action(Info.strategy!(User, :password), :sign_in, %{
               "email" => "admin@example.com",
               "password" => Seeds.demo_password()
             })

    assert :administrator in user.roles
  end
end
