defmodule Mercator.Catalog.ProductRelationTest do
  use Mercator.DataCase, async: true

  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  defp relate(product, related, kind, extra \\ %{}) do
    extra
    |> Map.merge(%{product_id: product.id, related_product_id: related.id, kind: kind})
    |> Catalog.relate_products(authorize?: false)
  end

  test "relates products as accessory, related or recommended" do
    boards = product_fixture()
    screws = product_fixture()
    oil = product_fixture()

    assert {:ok, _} = relate(boards, screws, :accessory)
    assert {:ok, _} = relate(boards, oil, :recommended, %{reason: %{"de" => "schützt das Holz"}})
    assert {:ok, _} = relate(boards, oil, :related)

    relations = Ash.load!(boards, relations: :related_product).relations
    assert Enum.map(relations, & &1.kind) |> Enum.sort() == [:accessory, :recommended, :related]
  end

  test "a product cannot be related to itself or twice in the same way" do
    product = product_fixture()
    other = product_fixture()

    assert {:error, %Ash.Error.Invalid{}} = relate(product, product, :related)
    assert {:ok, _} = relate(product, other, :related)
    assert {:error, %Ash.Error.Invalid{}} = relate(product, other, :related)
  end

  test "relations to invisible products are hidden" do
    product = product_fixture()
    {:ok, _} = relate(product, product_fixture(state: :draft), :accessory)
    {:ok, _} = relate(product, product_fixture(), :accessory)

    assert length(Ash.load!(product, :relations).relations) == 1
  end
end
