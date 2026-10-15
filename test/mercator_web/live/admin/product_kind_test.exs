defmodule MercatorWeb.Admin.ProductKindTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    manager = user_fixture(roles: [:productmanager])
    %{conn: log_in_user(conn, manager), manager: manager}
  end

  defp boards do
    product_fixture(
      kind: :variants,
      variants: [
        %{name: %{"de" => "3 m"}, prices: [%{amount: "18.60"}]},
        %{name: %{"de" => "4 m"}, prices: [%{amount: "24.80"}]}
      ]
    )
  end

  describe "change_kind (#103)" do
    test "keeps prices when a product becomes configurable and back", %{manager: manager} do
      product = product_fixture()

      assert {:ok, %{kind: :configurable, pricing: :per_unit} = product} =
               Catalog.change_product_kind(product, :configurable, actor: manager)

      assert {:ok, %{kind: :simple}} =
               Catalog.change_product_kind(product, :simple, actor: manager)

      [variant] =
        Catalog.get_product!(product.id, authorize?: false, load: [variants: :prices]).variants

      assert [%{amount: amount}] = variant.prices
      assert Decimal.equal?(amount, 100)
    end

    test "a product with several variants cannot become simple", %{manager: manager} do
      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.change_product_kind(boards(), :simple, actor: manager)
    end

    test "only product managers change the kind" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Catalog.change_product_kind(product_fixture(), :variants, actor: user_fixture())
    end

    test "the general form no longer changes the kind", %{manager: manager} do
      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.update_product(product_fixture(), %{kind: :variants}, actor: manager)
    end
  end

  describe "editor" do
    test "the tabs follow the kind at once", %{conn: conn} do
      product = product_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}")

      assert has_element?(view, "#tab-variants", "Preis & Lager")
      refute has_element?(view, "#tab-configurator")

      view |> element("#change-kind") |> render_click()
      view |> form("#kind-form", kind: %{kind: "configurable"}) |> render_submit()

      assert has_element?(view, "#product-kind", "Konfigurierbar")
      assert has_element?(view, "#tab-configurator")
      assert has_element?(view, "#tab-variants", "Artikel & Lieferzeit")
      refute has_element?(view, "#kind-modal")
    end

    test "refusing simple for several variants shows why", %{conn: conn} do
      product = boards()
      {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}")

      view |> element("#change-kind") |> render_click()
      view |> form("#kind-form", kind: %{kind: "simple"}) |> render_submit()

      assert has_element?(view, "#kind-modal")
      assert has_element?(view, "#flash-error")
      assert Catalog.get_product!(product.id, authorize?: false).kind == :variants
    end

    test "a simple product has one variant, a configurable one no prices", %{conn: conn} do
      product = product_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=variants")

      refute has_element?(view, "#new-variant")
      refute has_element?(view, "[data-sortable-handle]")
      assert has_element?(view, "table[id^=prices-]")

      {:ok, _product} = Catalog.change_product_kind(product, :configurable, authorize?: false)
      {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=variants")

      assert has_element?(view, "#configurator-price-note")
      refute has_element?(view, "table[id^=prices-]")
      refute has_element?(view, "#new-variant")
    end

    test "the variants tab of a variants product is unchanged", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/#{boards().id}?tab=variants")

      assert has_element?(view, "#new-variant")
      assert has_element?(view, "[data-sortable-handle]")
    end

    test "a tab the kind does not have falls back to general", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/admin/products/#{product_fixture().id}?tab=configurator")

      assert has_element?(view, "#product-form")
    end
  end
end
