defmodule MercatorWeb.CatalogLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup do
    root =
      category_fixture(name: %{"de" => "Bauholz", "en" => "Construction timber"}, slug: "bauholz")

    child = category_fixture(name: %{"de" => "Latten"}, slug: "latten", parent_id: root.id)

    _draft_child =
      category_fixture(
        name: %{"de" => "Geheim"},
        slug: "geheim",
        parent_id: root.id,
        state: :draft
      )

    batten =
      product_fixture(
        title: %{"de" => "Dachlatte", "en" => "Roof batten"},
        kind: :variants,
        new_arrival: true,
        variants: [
          %{
            number: "LATTE-4M",
            name: %{"de" => "4 m"},
            unit: :piece,
            prices: [%{amount: "3.40"}, %{amount: "3.00", min_quantity: 100}]
          },
          %{number: "LATTE-5M", name: %{"de" => "5 m"}, unit: :piece, prices: [%{amount: "4.25"}]}
        ]
      )

    beam =
      product_fixture(
        title: %{"de" => "Balken"},
        variants: [%{number: "BALKEN-1", unit: :m3, prices: [%{amount: "500"}]}]
      )

    draft = product_fixture(title: %{"de" => "Entwurf"}, state: :draft)

    Catalog.categorize!(child.id, batten.id, authorize?: false)
    Catalog.categorize!(root.id, beam.id, authorize?: false)
    Catalog.categorize!(root.id, draft.id, authorize?: false)

    Catalog.relate_products!(
      %{product_id: batten.id, related_product_id: beam.id, kind: :accessory},
      authorize?: false
    )

    %{root: root, child: child, batten: batten, beam: beam, draft: draft}
  end

  describe "category page" do
    test "shows breadcrumb, active subcategories and the products of the subtree", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/kategorien/bauholz")

      assert has_element?(view, "#category-name", "Bauholz")
      assert has_element?(view, "#category-tile-latten")
      refute has_element?(view, "#category-tile-geheim")
      assert has_element?(view, "#product-#{ctx.batten.id}")
      assert has_element?(view, "#product-#{ctx.beam.id}")
      refute has_element?(view, "#product-#{ctx.draft.id}")
      assert has_element?(view, "#product-count", "2")
    end

    test "a subcategory page has the parent in the breadcrumb", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/kategorien/latten")

      assert has_element?(view, "#breadcrumb a[href='/kategorien/bauholz']")
      assert has_element?(view, "#product-#{ctx.batten.id}")
      refute has_element?(view, "#product-#{ctx.beam.id}")
    end

    test "filters are applied and kept in the URL", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/kategorien/bauholz")

      view |> element("#filter-form") |> render_change(%{"new" => "1", "sort" => "position"})

      assert_patch(view, ~p"/kategorien/bauholz?new=1")
      assert has_element?(view, "#product-#{ctx.batten.id}")
      refute has_element?(view, "#product-#{ctx.beam.id}")

      view |> element("#reset-filters") |> render_click()
      assert_patch(view, ~p"/kategorien/bauholz")
      assert has_element?(view, "#product-#{ctx.beam.id}")
    end

    test "shows the from price of products with several variants", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/kategorien/latten")

      # 3.40 net + 20 % = 4.08 gross
      assert has_element?(view, "#product-#{ctx.batten.id} [data-role=price]", "4,08 €")
    end

    test "unknown and draft categories lead to the start page", ctx do
      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(ctx.conn, ~p"/kategorien/gibt-es-nicht")

      assert {:error, {:live_redirect, %{to: "/"}}} = live(ctx.conn, ~p"/kategorien/geheim")
    end
  end

  describe "product page" do
    test "shows title, price of the first variant, properties and accessories", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/produkte/#{ctx.batten.slug}")

      assert has_element?(view, "#product-title", "Dachlatte")
      assert has_element?(view, "#article-number", "LATTE-4M")
      assert has_element?(view, "#price-box", "4,08 €")
      assert has_element?(view, "#price-box", "inkl. 20 % MwSt.")
      assert has_element?(view, "#graduated-prices")
      assert has_element?(view, "#relations-accessory")
      assert has_element?(view, "#add-to-basket[disabled]")
    end

    test "switching the variant updates number and price", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/produkte/#{ctx.batten.slug}")

      view |> element("#variant-LATTE-5M") |> render_click()

      assert_patch(view, ~p"/produkte/#{ctx.batten.slug}?variant=LATTE-5M")
      assert has_element?(view, "#article-number", "LATTE-5M")
      # 4.25 net + 20 % = 5.10 gross
      assert has_element?(view, "#price-box", "5,10 €")
    end

    test "the total follows the quantity and graduated prices", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/produkte/#{ctx.batten.slug}")

      view |> element("#quantity-form") |> render_change(%{"quantity" => "100"})

      # 100 × 3.00 net = 300 net, 360 gross
      assert view |> element("#total") |> render() =~ "360,00 €"
    end

    test "rejects decimal quantities for pieces but accepts them for m³", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/produkte/#{ctx.batten.slug}")
      view |> element("#quantity-form") |> render_change(%{"quantity" => "2,5"})
      assert has_element?(view, "#quantity-error")

      {:ok, view, _html} = live(ctx.conn, ~p"/produkte/#{ctx.beam.slug}")
      view |> element("#quantity-form") |> render_change(%{"quantity" => "2,5"})
      refute has_element?(view, "#quantity-error")
      # 2.5 × 500 net = 1250 net, 1500 gross
      assert has_element?(view, "#total", "1.500,00 €")
    end

    test "is shown in English", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/produkte/#{ctx.batten.slug}?locale=en")

      assert has_element?(view, "#product-title", "Roof batten")
      assert view |> element("#price-box") |> render() =~ "€4.08"
    end

    test "draft products are not shown", ctx do
      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(ctx.conn, ~p"/produkte/#{ctx.draft.slug}")
    end
  end

  test "the start page and navigation list the top categories", ctx do
    html = ctx.conn |> get(~p"/") |> html_response(200)

    assert html =~ ~s(id="category-tile-bauholz")
    assert html =~ ~s(id="nav-bauholz")
  end
end
