defmodule MercatorWeb.Admin.ProductRelationsTabTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    %{
      conn: log_in_user(conn, user_fixture(roles: [:productmanager])),
      boards: product_fixture(number: "BH-DIELE", title: %{"de" => "Terrassendiele"}),
      screws: product_fixture(number: "BH-SCHRAUBEN", title: %{"de" => "Terrassenschrauben"}),
      oil: product_fixture(number: "BH-OEL", title: %{"de" => "Holzöl"})
    }
  end

  defp relations(product),
    do: Catalog.get_product!(product.id, authorize?: false, load: :relations).relations

  test "adds an accessory found by search", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.boards.id}?tab=relations")

    view |> element("#add-relation-accessory") |> render_click()
    view |> form("#relation-search-form", %{"query" => "schrauben"}) |> render_change()
    view |> element("#choose-#{ctx.screws.id}") |> render_click()
    view |> form("#relation-form") |> render_submit()

    assert [%{kind: :accessory, related_product_id: id}] = relations(ctx.boards)
    assert id == ctx.screws.id
    assert has_element?(view, "#relations-accessory", "Terrassenschrauben")
  end

  test "adds a recommendation with a reason and never offers the product itself", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.boards.id}?tab=relations")

    view |> element("#add-relation-recommended") |> render_click()
    view |> form("#relation-search-form", %{"query" => "BH-"}) |> render_change()
    refute has_element?(view, "#choose-#{ctx.boards.id}")

    view |> element("#choose-#{ctx.oil.id}") |> render_click()

    view
    |> form("#relation-form", %{"reason" => %{"de" => "schützt das Holz"}})
    |> render_submit()

    assert [%{kind: :recommended, reason: %{"de" => "schützt das Holz"}}] = relations(ctx.boards)
  end

  test "deletes a relation", ctx do
    {:ok, relation} =
      Catalog.relate_products(
        %{product_id: ctx.boards.id, related_product_id: ctx.oil.id, kind: :related},
        authorize?: false
      )

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.boards.id}?tab=relations")
    view |> element("#delete-relation-#{relation.id}") |> render_click()

    assert relations(ctx.boards) == []
  end
end
