defmodule Mercator.Sales.GtcTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.{Clock, Sales}

  defp seed(version, text),
    do: Ash.Seed.seed!(Sales.Gtc, %{version: version, text: %{"de" => text}})

  setup do
    %{admin: user_fixture(roles: [:administrator]), today: Clock.today()}
  end

  test "the current version is the newest whose date has come (#92)", %{
    admin: admin,
    today: today
  } do
    assert Sales.current_gtc!() == nil

    seed(Date.add(today, -300), "Alt")
    seed(Date.add(today, -10), "Gültig")
    Sales.create_gtc!(%{version: Date.add(today, 30), text: %{"de" => "Künftig"}}, actor: admin)

    assert %{text: %{"de" => "Gültig"}} = Sales.current_gtc!()
  end

  test "new versions are dated today or later", %{admin: admin, today: today} do
    assert {:error, %Ash.Error.Invalid{}} =
             Sales.create_gtc(%{version: Date.add(today, -1), text: %{"de" => "x"}}, actor: admin)

    assert {:ok, gtc} =
             Sales.create_gtc(%{version: today, text: %{"de" => "Ab heute"}}, actor: admin)

    assert Sales.current_gtc!().id == gtc.id
  end

  test "versions in force are fixed; upcoming ones can be edited and deleted", %{
    admin: admin,
    today: today
  } do
    in_force = seed(Date.add(today, -10), "Gültig")
    assert {:error, _} = Sales.update_gtc(in_force, %{text: %{"de" => "geändert"}}, actor: admin)
    assert {:error, _} = Sales.destroy_gtc(in_force, actor: admin)

    upcoming =
      Sales.create_gtc!(%{version: Date.add(today, 30), text: %{"de" => "Entwurf"}}, actor: admin)

    upcoming = Sales.update_gtc!(upcoming, %{text: %{"de" => "Künftig"}}, actor: admin)
    assert upcoming.text == %{"de" => "Künftig"}

    # moving an upcoming version into the past is not possible either
    assert {:error, _} = Sales.update_gtc(upcoming, %{version: Date.add(today, -1)}, actor: admin)
    assert :ok = Sales.destroy_gtc(upcoming, actor: admin)
  end

  test "only administrators and content managers publish terms", %{today: today} do
    attrs = %{version: Date.add(today, 1), text: %{"de" => "AGB"}}

    assert {:error, %Ash.Error.Forbidden{}} = Sales.create_gtc(attrs, actor: user_fixture())
    assert {:error, %Ash.Error.Forbidden{}} = Sales.create_gtc(attrs)
    assert {:ok, _} = Sales.create_gtc(attrs, actor: user_fixture(roles: [:contentmanager]))
  end

  test "one version per date", %{admin: admin, today: today} do
    attrs = %{version: Date.add(today, 1), text: %{"de" => "AGB"}}

    assert {:ok, _} = Sales.create_gtc(attrs, actor: admin)
    assert {:error, %Ash.Error.Invalid{}} = Sales.create_gtc(attrs, actor: admin)
  end
end
