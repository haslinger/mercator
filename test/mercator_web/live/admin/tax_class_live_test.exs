defmodule MercatorWeb.Admin.TaxClassLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture(roles: [:administrator]))}
  end

  test "only administrators manage tax classes" do
    assert {:error, {:redirect, %{to: "/"}}} =
             build_conn()
             |> log_in_user(user_fixture(roles: [:productmanager]))
             |> live(~p"/admin/tax-classes")
  end

  test "creates and edits a tax class", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/tax-classes")

    view |> element("#new-tax-class") |> render_click()

    view
    |> form("#tax-class-form",
      form: %{key: "super_reduced", name: %{de: "Ermäßigt 10 %"}, rate: "10"}
    )
    |> render_submit()

    {:ok, tax_class} = Catalog.get_tax_class_by_key("super_reduced")
    assert Decimal.equal?(tax_class.rate, 10)

    view |> element("#edit-tax-class-#{tax_class.id}") |> render_click()
    view |> form("#tax-class-form", form: %{rate: "9"}) |> render_submit()
    assert Decimal.equal?(Catalog.get_tax_class!(tax_class.id).rate, 9)
  end

  test "deletes only unused tax classes", %{conn: conn} do
    used = tax_class_fixture()
    product_fixture(tax_class_id: used.id)
    unused = tax_class_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/tax-classes")

    view |> element("#delete-tax-class-#{used.id}") |> render_click()
    assert {:ok, _} = Catalog.get_tax_class(used.id)
    assert render(view) =~ "noch von Produkten verwendet"

    view |> element("#delete-tax-class-#{unused.id}") |> render_click()
    assert {:error, _} = Catalog.get_tax_class(unused.id)
  end
end
