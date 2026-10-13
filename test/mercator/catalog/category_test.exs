defmodule Mercator.Catalog.CategoryTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  describe "tree" do
    test "a root category's path is its own id, a child's path extends the parent's" do
      root = category_fixture()
      child = category_fixture(parent_id: root.id)

      assert root.path == [root.id]
      assert child.path == [root.id, child.id]
    end

    test "roots and children are ordered by position" do
      second = category_fixture(position: 2)
      first = category_fixture(position: 1)
      b = category_fixture(parent_id: first.id, position: 2)
      a = category_fixture(parent_id: first.id, position: 1)

      assert ids(Catalog.list_root_categories!()) == [first.id, second.id]
      assert ids(Catalog.list_child_categories!(first.id)) == [a.id, b.id]
    end

    test "ancestors are listed root first, the subtree includes all descendants" do
      root = category_fixture()
      child = category_fixture(parent_id: root.id)
      grandchild = category_fixture(parent_id: child.id)
      _other = category_fixture()

      assert ids(Catalog.list_category_ancestors!(grandchild.id)) == [root.id, child.id]
      assert ids(Catalog.list_category_ancestors!(root.id)) == []

      assert Enum.sort(ids(Catalog.list_category_subtree!(root.id))) ==
               Enum.sort([root.id, child.id, grandchild.id])
    end

    test "moving a category also moves its descendants" do
      old_parent = category_fixture()
      new_parent = category_fixture()
      moved = category_fixture(parent_id: old_parent.id)
      below = category_fixture(parent_id: moved.id)

      moved = Catalog.move_category!(moved, new_parent.id, authorize?: false)

      assert moved.path == [new_parent.id, moved.id]
      assert Catalog.get_category!(below.id).path == [new_parent.id, moved.id, below.id]
      assert ids(Catalog.list_category_subtree!(old_parent.id)) == [old_parent.id]
    end

    test "moving a category to the top level" do
      parent = category_fixture()
      child = category_fixture(parent_id: parent.id)

      assert Catalog.move_category!(child, nil, authorize?: false).path == [child.id]
    end

    test "a category cannot be moved below itself or its descendants" do
      root = category_fixture()
      child = category_fixture(parent_id: root.id)

      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.move_category(root, child.id, authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.move_category(root, root.id, authorize?: false)
    end

    test "a category with children cannot be deleted" do
      root = category_fixture()
      _child = category_fixture(parent_id: root.id)

      assert {:error, _} = Catalog.destroy_category(root, authorize?: false)
    end

    test "an unknown parent is rejected" do
      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.create_category(%{name: %{"de" => "X"}, parent_id: Ash.UUID.generate()},
                 authorize?: false
               )
    end
  end

  describe "slugs" do
    test "are generated from the German name" do
      category =
        category_fixture(name: %{"de" => "Kanthölzer & Balken", "en" => "Squared timber"})

      assert category.slug == "kanthoelzer-balken"
      assert {:ok, %{id: id}} = Catalog.get_category_by_slug("kanthoelzer-balken")
      assert id == category.id
    end

    test "can be given explicitly, must be valid and unique" do
      assert category_fixture(slug: "bau-holz").slug == "bau-holz"

      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.create_category(%{name: %{"de" => "Bauholz"}, slug: "Bau Holz"},
                 authorize?: false
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.create_category(%{name: %{"de" => "Bauholz"}, slug: "bau-holz"},
                 authorize?: false
               )
    end
  end

  describe "states and visibility" do
    test "new categories are drafts and visible to staff only" do
      draft = category_fixture(state: :draft)
      manager = user_fixture(roles: [:productmanager])

      assert draft.state == :draft
      assert {:error, _} = Catalog.get_category(draft.id)
      assert {:error, _} = Catalog.get_category(draft.id, actor: user_fixture())
      assert {:ok, _} = Catalog.get_category(draft.id, actor: manager)
    end

    test "active and hidden categories are visible to everybody" do
      active = category_fixture(state: :active)
      hidden = category_fixture(state: :hidden)

      assert {:ok, _} = Catalog.get_category(active.id)
      assert {:ok, _} = Catalog.get_category(hidden.id)
    end

    test "state transitions" do
      category = category_fixture(state: :draft)

      category = Catalog.activate_category!(category, authorize?: false)
      assert category.state == :active
      category = Catalog.hide_category!(category, authorize?: false)
      assert category.state == :hidden
      category = Catalog.deactivate_category!(category, authorize?: false)
      assert category.state == :draft

      assert {:error, _} = Catalog.deactivate_category(category, authorize?: false)
    end
  end

  describe "permissions" do
    test "product managers and administrators manage categories" do
      for roles <- [[:productmanager], [:administrator]] do
        actor = user_fixture(roles: roles)

        assert {:ok, category} =
                 Catalog.create_category(%{name: %{"de" => "Neu #{inspect(roles)}"}},
                   actor: actor
                 )

        assert {:ok, _} = Catalog.activate_category(category, actor: actor)
      end
    end

    test "customers and other staff cannot change categories" do
      category = category_fixture()

      for actor <- [nil, user_fixture(), user_fixture(roles: [:sales, :contentmanager])] do
        assert {:error, %Ash.Error.Forbidden{}} =
                 Catalog.create_category(%{name: %{"de" => "Nope"}}, actor: actor)

        assert {:error, %Ash.Error.Forbidden{}} =
                 Catalog.update_category(category, %{position: 9}, actor: actor)
      end
    end
  end

  defp ids(records), do: Enum.map(records, & &1.id)
end
