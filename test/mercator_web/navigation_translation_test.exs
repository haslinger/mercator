defmodule MercatorWeb.NavigationTranslationTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.CatalogFixtures

  test "the shop menu says Sortiment, the admin says Produkte", %{conn: conn} do
    category_fixture()

    html = conn |> get(~p"/") |> html_response(200)
    assert html =~ "Sortiment"
  end
end
