defmodule Mercator.Accounts.AddressTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Accounts

  @attrs %{
    name: "Karl Luchs",
    street: "Waldweg 3",
    postcode: "6020",
    city: "Innsbruck",
    country: "AT"
  }

  defp create(user, attrs \\ %{}),
    do: Accounts.create_address(Map.merge(@attrs, attrs), actor: user)

  test "creates an address for the signed-in user" do
    user = user_fixture()

    assert {:ok, address} = create(user)
    assert address.user_id == user.id
    assert {:error, _} = Accounts.create_address(@attrs)
  end

  test "postcodes must match the country" do
    user = user_fixture()

    assert {:error, %Ash.Error.Invalid{}} = create(user, %{postcode: "60200"})
    assert {:ok, _} = create(user, %{country: "DE", postcode: "80331", city: "München"})
    assert {:error, %Ash.Error.Invalid{}} = create(user, %{country: "DE", postcode: "8033"})
    assert {:ok, _} = create(user, %{country: "NL", postcode: "1011 AB", city: "Amsterdam"})
    assert {:error, %Ash.Error.Invalid{}} = create(user, %{country: "NL", postcode: "2513"})
  end

  test "postcode formats of other countries" do
    valid = [
      NL: "2513AA",
      PL: "00-950",
      CZ: "110 00",
      SE: "11122",
      PT: "1100-148",
      LU: "L-1009",
      IE: "D02 X285",
      MT: "VLT 1117",
      RO: "010011"
    ]

    invalid = [PL: "00950", CZ: "1100", PT: "1100", RO: "01001", IE: "D02", CH: "80331"]

    for {country, postcode} <- valid do
      assert Regex.match?(Mercator.Countries.postcode_format("#{country}"), postcode),
             "#{country} #{postcode}"
    end

    for {country, postcode} <- invalid do
      refute Regex.match?(Mercator.Countries.postcode_format("#{country}"), postcode),
             "#{country} #{postcode}"
    end
  end

  test "only known countries" do
    assert {:error, %Ash.Error.Invalid{}} =
             create(user_fixture(), %{country: "US", postcode: "10001"})
  end

  test "only one default billing and one default delivery address" do
    user = user_fixture()
    {:ok, first} = create(user, %{default_billing: true, default_shipping: true})
    {:ok, second} = create(user, %{default_billing: true})

    [a, b] = Accounts.list_my_addresses!(actor: user)
    assert a.id == second.id and a.default_billing
    assert b.id == first.id and not b.default_billing and b.default_shipping
  end

  test "users only see and change their own addresses" do
    owner = user_fixture()
    {:ok, address} = create(owner)
    other = user_fixture()

    assert Accounts.list_my_addresses!(actor: other) == []
    assert {:error, _} = Accounts.get_address(address.id, actor: other)

    assert {:error, %Ash.Error.Forbidden{}} =
             Accounts.update_address(address, %{city: "Hall"}, actor: other)
  end

  test "delivery countries are configured" do
    assert Mercator.Countries.delivery() == ~w(AT DE IT)
    assert "CH" in Mercator.Countries.billing()
  end
end
