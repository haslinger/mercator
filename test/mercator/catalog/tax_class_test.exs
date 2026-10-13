defmodule Mercator.Catalog.TaxClassTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Catalog

  @attrs %{key: "reduced", name: %{"de" => "ermäßigt 13 %", "en" => "reduced 13 %"}, rate: "13"}

  test "an administrator creates and updates tax classes" do
    admin = user_fixture(roles: [:administrator])

    assert {:ok, tax_class} = Catalog.create_tax_class(@attrs, actor: admin)
    assert Decimal.equal?(tax_class.rate, 13)
    assert tax_class.name["de"] == "ermäßigt 13 %"

    assert {:ok, updated} = Catalog.update_tax_class(tax_class, %{rate: "10"}, actor: admin)
    assert Decimal.equal?(updated.rate, 10)
  end

  test "everybody can read tax classes" do
    admin = user_fixture(roles: [:administrator])
    Catalog.create_tax_class!(@attrs, actor: admin)

    assert {:ok, %{key: "reduced"}} = Catalog.get_tax_class_by_key("reduced")
  end

  test "only administrators may change tax classes" do
    for actor <- [nil, user_fixture(), user_fixture(roles: [:productmanager, :sales])] do
      assert {:error, %Ash.Error.Forbidden{}} = Catalog.create_tax_class(@attrs, actor: actor)
    end
  end

  test "keys are unique and lowercase, rates between 0 and 100, a German name is required" do
    admin = user_fixture(roles: [:administrator])
    Catalog.create_tax_class!(@attrs, actor: admin)

    assert {:error, %Ash.Error.Invalid{}} = Catalog.create_tax_class(@attrs, actor: admin)

    for invalid <- [
          %{@attrs | key: "Reduced 13"},
          %{@attrs | key: "other", rate: "120"},
          %{@attrs | key: "other", name: %{"en" => "reduced"}}
        ] do
      assert {:error, %Ash.Error.Invalid{}} = Catalog.create_tax_class(invalid, actor: admin)
    end
  end
end
