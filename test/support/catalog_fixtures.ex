defmodule Mercator.CatalogFixtures do
  @moduledoc """
  Test helpers for catalogue data. Fixtures bypass policies.
  """

  alias Mercator.Catalog

  def category_fixture(attrs \\ %{}) do
    {state, attrs} = Map.pop(Map.new(attrs), :state, :active)
    name = Map.get(attrs, :name, %{"de" => "Kategorie #{System.unique_integer([:positive])}"})

    category =
      attrs
      |> Map.put(:name, name)
      |> Catalog.create_category!(authorize?: false)

    case state do
      :draft -> category
      :active -> Catalog.activate_category!(category, authorize?: false)
      :hidden -> Catalog.hide_category!(category, authorize?: false)
    end
  end
end
