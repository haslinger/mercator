defmodule MercatorWeb.Admin.ProductImagesTabTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture(roles: [:productmanager])), product: product_fixture()}
  end

  defp images(product),
    do: Catalog.get_product!(product.id, authorize?: false, load: :images).images

  defp upload(view, files) do
    entries =
      for {name, path} <- files do
        %{name: name, content: File.read!(path), type: "image/jpeg"}
      end

    input = file_input(view, "#image-upload-form", :images, entries)
    for {name, _} <- files, do: render_upload(input, name)
    view |> form("#image-upload-form") |> render_submit()
  end

  test "uploads several images in order", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=images")
    assert has_element?(view, "#no-images")

    upload(view, [{"front.jpg", "test/fixtures/wood.jpg"}, {"side.jpg", "test/fixtures/wood.jpg"}])

    assert [first, second] = images(product)
    assert {first.original_filename, second.original_filename} == {"front.jpg", "side.jpg"}
    assert first.alt == product.title
    assert has_element?(view, "#image-#{first.id}", "Hauptbild")
  end

  test "reports files that are not images", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=images")

    upload(view, [{"fake.jpg", "test/fixtures/not_an_image.txt"}])

    assert images(product) == []
    assert render(view) =~ "kein lesbares Bild"
  end

  test "sorts and deletes images", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product.id}?tab=images")
    upload(view, [{"a.jpg", "test/fixtures/wood.jpg"}, {"b.jpg", "test/fixtures/wood.jpg"}])
    [a, b] = images(product)

    view |> element("#image-gallery") |> render_hook("reorder", %{"id" => b.id, "index" => 0})
    assert Enum.map(images(product), & &1.id) == [b.id, a.id]

    view |> element("#delete-image-#{a.id}") |> render_click()
    assert Enum.map(images(product), & &1.id) == [b.id]
  end
end
