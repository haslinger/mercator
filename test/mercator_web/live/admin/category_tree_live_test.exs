defmodule MercatorWeb.Admin.CategoryTreeLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    manager = user_fixture(roles: [:productmanager])

    wood = category_fixture(name: %{"de" => "Holz"}, slug: "holz", position: 1)

    boards =
      category_fixture(
        name: %{"de" => "Bretter"},
        slug: "bretter",
        parent_id: wood.id,
        position: 1
      )

    beams =
      category_fixture(name: %{"de" => "Balken"}, slug: "balken", parent_id: wood.id, position: 2)

    energy =
      category_fixture(name: %{"de" => "Energie"}, slug: "energie", position: 2, state: :draft)

    %{
      conn: log_in_user(conn, manager),
      manager: manager,
      wood: wood,
      boards: boards,
      beams: beams,
      energy: energy
    }
  end

  defp reload(category), do: Catalog.get_category!(category.id, authorize?: false)

  test "only product managers and administrators get in", %{wood: _} do
    assert {:error, {:redirect, %{to: "/"}}} =
             build_conn()
             |> log_in_user(user_fixture(roles: [:sales]))
             |> live(~p"/admin/categories")
  end

  test "shows the tree with states, including drafts", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    assert has_element?(view, "#category-#{ctx.wood.id} #category-#{ctx.boards.id}")
    assert has_element?(view, "#category-#{ctx.energy.id}", "Entwurf")
  end

  test "sorting within the same parent renumbers the positions", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    render_hook(view, "move", %{"id" => ctx.beams.id, "parent_id" => ctx.wood.id, "index" => 0})

    assert reload(ctx.beams).position == 1
    assert reload(ctx.boards).position == 2
  end

  test "moving into another category changes the parent and path", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    render_hook(view, "move", %{"id" => ctx.boards.id, "parent_id" => ctx.energy.id, "index" => 0})

    moved = reload(ctx.boards)
    assert moved.parent_id == ctx.energy.id
    assert moved.path == [ctx.energy.id, ctx.boards.id]
    assert has_element?(view, "#category-#{ctx.energy.id} #category-#{ctx.boards.id}")
  end

  test "moving to the top level", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    render_hook(view, "move", %{"id" => ctx.boards.id, "parent_id" => nil, "index" => 0})

    assert reload(ctx.boards).parent_id == nil
    assert reload(ctx.boards).position == 1
  end

  test "a category cannot be moved below its own child", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    render_hook(view, "move", %{"id" => ctx.wood.id, "parent_id" => ctx.boards.id, "index" => 0})

    assert reload(ctx.wood).parent_id == nil
    assert render(view) =~ "nicht unter sich selbst"
  end

  test "creates a subcategory with a slug from the German name", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    view |> element("#add-child-#{ctx.wood.id}") |> render_click()
    assert_patch(view, ~p"/admin/categories/new?parent=#{ctx.wood.id}")

    view
    |> form("#category-form", form: %{name: %{de: "Latten & Staffeln", en: "Battens"}})
    |> render_submit()

    assert_patch(view, ~p"/admin/categories")
    assert {:ok, created} = Catalog.get_category_by_slug("latten-staffeln", authorize?: false)
    assert created.parent_id == ctx.wood.id
    assert created.state == :draft
  end

  test "shows validation errors", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories/new")

    html =
      view
      |> form("#category-form", form: %{name: %{de: "", en: "Only English"}})
      |> render_submit()

    assert html =~ "Übersetzung für de fehlt"
  end

  test "edits a category", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories/#{ctx.beams.id}/edit")

    view |> form("#category-form", form: %{name: %{de: "Kanthölzer"}}) |> render_submit()

    assert reload(ctx.beams).name["de"] == "Kanthölzer"
  end

  test "changes the state", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    view |> element("#transition-#{ctx.energy.id}-active") |> render_click()
    assert reload(ctx.energy).state == :active

    view |> element("#transition-#{ctx.energy.id}-hidden") |> render_click()
    assert reload(ctx.energy).state == :hidden
  end

  test "deletes only empty categories", ctx do
    Catalog.categorize!(ctx.beams.id, product_fixture().id, authorize?: false)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/categories")

    view |> element("#delete-#{ctx.wood.id}") |> render_click()
    assert {:ok, _} = Catalog.get_category(ctx.wood.id, authorize?: false)

    view |> element("#delete-#{ctx.beams.id}") |> render_click()
    assert {:ok, _} = Catalog.get_category(ctx.beams.id, authorize?: false)

    view |> element("#delete-#{ctx.boards.id}") |> render_click()
    assert {:error, _} = Catalog.get_category(ctx.boards.id, authorize?: false)
  end
end
