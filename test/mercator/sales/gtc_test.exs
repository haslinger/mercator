defmodule Mercator.Sales.GtcTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Sales

  test "the newest version is the current one" do
    admin = user_fixture(roles: [:administrator])
    assert Sales.current_gtc!() == nil

    Sales.create_gtc!(%{version: ~D[2026-01-01], text: %{"de" => "Alt"}}, actor: admin)
    Sales.create_gtc!(%{version: ~D[2026-10-01], text: %{"de" => "Neu"}}, actor: admin)

    assert %{text: %{"de" => "Neu"}} = Sales.current_gtc!()
  end

  test "only administrators and content managers publish terms" do
    attrs = %{version: ~D[2026-10-01], text: %{"de" => "AGB"}}

    assert {:error, %Ash.Error.Forbidden{}} = Sales.create_gtc(attrs, actor: user_fixture())
    assert {:error, %Ash.Error.Forbidden{}} = Sales.create_gtc(attrs)
    assert {:ok, _} = Sales.create_gtc(attrs, actor: user_fixture(roles: [:contentmanager]))
  end

  test "one version per date" do
    admin = user_fixture(roles: [:administrator])
    attrs = %{version: ~D[2026-10-01], text: %{"de" => "AGB"}}

    assert {:ok, _} = Sales.create_gtc(attrs, actor: admin)
    assert {:error, %Ash.Error.Invalid{}} = Sales.create_gtc(attrs, actor: admin)
  end
end
