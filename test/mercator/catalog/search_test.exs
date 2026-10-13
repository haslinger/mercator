defmodule Mercator.Catalog.SearchTest do
  use Mercator.DataCase, async: true

  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup do
    larch =
      product_fixture(
        number: "BH-TD-LAE",
        title: %{"de" => "Terrassendiele Lärche", "en" => "Decking board larch"},
        description: %{"de" => "Sibirische Lärche, glatt"}
      )

    firewood =
      product_fixture(
        number: "BH-SCHEIT-BUCHE",
        title: %{"de" => "Brennholz Buche", "en" => "Beech firewood"},
        description: %{"de" => "Ofenfertig, kammergetrocknet"}
      )

    draft =
      product_fixture(
        number: "BH-ENTWURF",
        title: %{"de" => "Lärchenbrett Entwurf"},
        state: :draft
      )

    %{larch: larch, firewood: firewood, draft: draft}
  end

  defp search(query), do: query |> Catalog.search_products!() |> Enum.map(& &1.number)

  test "finds German words with and without umlauts", %{larch: larch} do
    assert search("Lärche") == [larch.number]
    assert search("larche") == [larch.number]
  end

  test "finds word prefixes and parts of compounds", %{larch: larch, firewood: firewood} do
    assert search("Terrasse") == [larch.number]
    assert search("holz") == [firewood.number]
  end

  test "finds English words and descriptions", %{larch: larch, firewood: firewood} do
    assert search("decking") == [larch.number]
    assert search("kammergetrocknet") == [firewood.number]
  end

  test "all words must match", %{larch: larch} do
    assert search("Lärche glatt") == [larch.number]
    assert search("Lärche Buche") == []
  end

  test "finds article number prefixes", %{firewood: firewood} do
    assert search("bh-scheit") == [firewood.number]
  end

  test "ranks title matches before description matches" do
    in_title = product_fixture(title: %{"de" => "Zirbenbrett"})

    in_text =
      product_fixture(title: %{"de" => "Schneidbrett"}, description: %{"de" => "aus Zirbe"})

    assert search("zirbe") == [in_title.number, in_text.number]
  end

  test "does not show draft products", %{draft: draft} do
    refute draft.number in search("Lärchenbrett")
  end

  test "empty or punctuation-only queries find nothing and never fail" do
    assert search("") == []
    assert search("  ") == []
    assert search("& | ! ' :*") == []
    assert is_list(search("Lärche & 'Buche' (glatt)!"))
  end
end
