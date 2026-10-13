defmodule MercatorWeb.AddressesLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Accounts

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "requires sign-in" do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), ~p"/account/addresses")
  end

  test "adds the first address as default billing and delivery address", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/account/addresses")
    assert has_element?(view, "#no-addresses")

    view |> element("#new-address") |> render_click()

    view
    |> form("#address-form",
      form: %{
        name: "Karl Luchs",
        street: "Waldweg 3",
        postcode: "6020",
        city: "Innsbruck",
        country: "AT"
      }
    )
    |> render_submit()

    assert [address] = Accounts.list_my_addresses!(actor: user)
    assert address.default_billing and address.default_shipping
    assert has_element?(view, "#address-#{address.id}", "Innsbruck")
  end

  test "shows validation errors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/account/addresses")
    view |> element("#new-address") |> render_click()

    html =
      view
      |> form("#address-form",
        form: %{
          name: "Karl",
          street: "Waldweg 3",
          postcode: "123",
          city: "Innsbruck",
          country: "AT"
        }
      )
      |> render_submit()

    assert html =~ "keine gültige Postleitzahl"
  end

  test "changes the default, edits and deletes", %{conn: conn, user: user} do
    attrs = %{
      name: "Karl Luchs",
      street: "Waldweg 3",
      postcode: "6020",
      city: "Innsbruck",
      country: "AT"
    }

    {:ok, home} = Accounts.create_address(Map.put(attrs, :default_billing, true), actor: user)
    {:ok, work} = Accounts.create_address(%{attrs | street: "Sägewerkstraße 1"}, actor: user)

    {:ok, view, _html} = live(conn, ~p"/account/addresses")

    view |> element("#default-billing-#{work.id}") |> render_click()
    assert Accounts.get_address!(work.id, actor: user).default_billing
    refute Accounts.get_address!(home.id, actor: user).default_billing

    view |> element("#edit-address-#{home.id}") |> render_click()
    view |> form("#address-form", form: %{city: "Hall in Tirol"}) |> render_submit()
    assert Accounts.get_address!(home.id, actor: user).city == "Hall in Tirol"

    view |> element("#delete-address-#{home.id}") |> render_click()
    assert {:error, _} = Accounts.get_address(home.id, actor: user)
  end

  test "the account page links to the address book", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/account")

    assert has_element?(view, "#addresses-link")
  end
end
