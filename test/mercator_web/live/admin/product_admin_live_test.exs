defmodule MercatorWeb.Admin.ProductAdminLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    manager = user_fixture(roles: [:productmanager])
    wood = category_fixture(name: %{"de" => "Holz"}, slug: "holz")
    boards = category_fixture(name: %{"de" => "Bretter"}, slug: "bretter", parent_id: wood.id)
    energy = category_fixture(name: %{"de" => "Energie"}, slug: "energie")

    larch =
      product_fixture(number: "BH-LAE", title: %{"de" => "Lärchenbrett", "en" => "Larch board"})

    pellets = product_fixture(number: "BH-PEL", title: %{"de" => "Pellets"})
    draft = product_fixture(number: "BH-NEU", title: %{"de" => "Neuheit"}, state: :draft)

    Catalog.categorize!(boards.id, larch.id, authorize?: false)
    Catalog.categorize!(energy.id, pellets.id, authorize?: false)

    %{
      conn: log_in_user(conn, manager),
      tax_class: tax_class_fixture(),
      wood: wood,
      boards: boards,
      energy: energy,
      larch: larch,
      pellets: pellets,
      draft: draft
    }
  end

  describe "product list" do
    test "is only for product managers and administrators", %{larch: _} do
      assert {:error, {:redirect, %{to: "/"}}} =
               build_conn()
               |> log_in_user(user_fixture(roles: [:sales]))
               |> live(~p"/admin/products")
    end

    test "lists all products including drafts", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products")

      for product <- [ctx.larch, ctx.pellets, ctx.draft] do
        assert has_element?(view, "#product-#{product.id}")
      end
    end

    test "filters by category including subcategories, state and search", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products?category=#{ctx.wood.id}")
      assert has_element?(view, "#product-#{ctx.larch.id}")
      refute has_element?(view, "#product-#{ctx.pellets.id}")

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products?state=draft")
      assert has_element?(view, "#product-#{ctx.draft.id}")
      refute has_element?(view, "#product-#{ctx.larch.id}")

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products")
      view |> element("#product-filters") |> render_change(%{"q" => "larch"})
      assert_patch(view, ~p"/admin/products?q=larch")
      assert has_element?(view, "#product-#{ctx.larch.id}")
      refute has_element?(view, "#product-#{ctx.pellets.id}")
    end

    test "activates and discontinues products", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products")

      view |> element("#activate-#{ctx.draft.id}") |> render_click()
      assert Catalog.get_product!(ctx.draft.id, authorize?: false).state == :active

      view |> element("#discontinue-#{ctx.larch.id}") |> render_click()
      assert Catalog.get_product!(ctx.larch.id, authorize?: false).state == :discontinued
    end

    test "creates a product and opens the editor", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/new")

      view
      |> form("#new-product-form",
        form: %{
          number: "BH-HOCKER",
          title: %{de: "Hocker Lärche"},
          kind: "simple",
          tax_class_id: ctx.tax_class.id
        }
      )
      |> render_submit()

      {:ok, product} = Catalog.get_product_by_number("BH-HOCKER", authorize?: false)
      assert product.state == :draft
      assert product.slug == "hocker-laerche"
      assert_redirect(view, ~p"/admin/products/#{product.id}")
    end

    test "rejects invalid article numbers", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/new")

      html =
        view
        |> form("#new-product-form",
          form: %{
            number: "bh hocker",
            title: %{de: "Hocker"},
            kind: "simple",
            tax_class_id: ctx.tax_class.id
          }
        )
        |> render_submit()

      assert html =~ "hat ein ungültiges Format" or html =~ "must match"
      assert {:error, _} = Catalog.get_product_by_number("bh hocker", authorize?: false)
    end
  end

  describe "product editor, general tab" do
    test "saves texts, highlights and categories", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.larch.id}")

      view
      |> form("#product-form",
        form: %{
          title: %{de: "Lärchenbrett gehobelt", en: "Larch board planed"},
          bestseller: "true"
        },
        highlights: %{
          de: "witterungsbeständig\n\nnatürlich schön",
          en: "weatherproof\n\nnaturally beautiful"
        },
        category_ids: [ctx.energy.id]
      )
      |> render_submit()

      product = Catalog.get_product!(ctx.larch.id, authorize?: false, load: :categories)
      assert product.title["de"] == "Lärchenbrett gehobelt"
      assert product.bestseller

      assert product.highlights == [
               %{"de" => "witterungsbeständig", "en" => "weatherproof"},
               %{"de" => "natürlich schön", "en" => "naturally beautiful"}
             ]

      assert Enum.map(product.categories, & &1.id) == [ctx.energy.id]
    end

    test "ignores the _unused_ keys LiveView sends for untouched highlights", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.larch.id}")

      highlights = %{"_unused_de" => "", "_unused_en" => "", "de" => "robust", "en" => "sturdy"}
      form = %{"title" => %{"de" => "Lärche 36 m", "en" => "Larch 36 m"}}

      render_change(view, "validate", %{"form" => form, "highlights" => highlights})
      refute has_element?(view, "#highlights-_unused_de")

      render_submit(view, "save", %{"form" => form, "highlights" => highlights})

      product = Catalog.get_product!(ctx.larch.id, authorize?: false)
      assert product.title["de"] == "Lärche 36 m"
      assert product.highlights == [%{"de" => "robust", "en" => "sturdy"}]
    end

    test "activates a product from the editor", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/products/#{ctx.draft.id}")

      view |> element("#activate-product") |> render_click()

      assert Catalog.get_product!(ctx.draft.id, authorize?: false).state == :active
      assert has_element?(view, "#view-in-shop")
    end

    test "unknown products lead back to the list", ctx do
      assert {:error, {:live_redirect, %{to: "/admin/products"}}} =
               live(ctx.conn, ~p"/admin/products/#{Ash.UUID.generate()}")
    end
  end
end
