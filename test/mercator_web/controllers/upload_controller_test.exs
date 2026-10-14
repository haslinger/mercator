defmodule MercatorWeb.UploadControllerTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.CatalogFixtures

  alias Mercator.Catalog
  alias Mercator.Catalog.Image
  alias Mercator.Content
  alias Mercator.Content.Asset

  setup do
    {:ok, image} =
      Catalog.upload_image(
        %{product_id: product_fixture().id, source_path: "test/fixtures/wood.jpg"},
        authorize?: false
      )

    %{image: image}
  end

  test "serves uploaded images with long caching", %{conn: conn, image: image} do
    conn = get(conn, Image.url(image, :thumb))

    assert response(conn, 200)
    assert response_content_type(conn, :webp) =~ "image/webp"
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
  end

  test "serves PDFs and images of the media library", %{conn: conn} do
    upload = fn source, name ->
      Content.upload_asset!(
        %{source_path: source, original_filename: name, tags: ["test"]},
        authorize?: false
      )
    end

    pdf = upload.("test/fixtures/sample.pdf", "Preisliste.pdf")
    conn = get(conn, Asset.url(pdf))
    assert response(conn, 200) =~ "%PDF-"
    assert response_content_type(conn, :pdf) =~ "application/pdf"

    image = upload.("test/fixtures/wood.jpg", "wood.jpg")
    assert build_conn() |> get(Asset.url(image, :wide)) |> response(200)
  end

  test "does not leave the upload directory", %{conn: conn} do
    assert conn |> get("/uploads/../mix.exs") |> response(404)
    assert conn |> get("/uploads/images/%2E%2E/%2E%2E/mix.exs") |> response(404)
    assert conn |> get("/uploads/images/nope/thumb.webp") |> response(404)
  end

  test "the product page and cards show the image", %{conn: conn, image: image} do
    product = Catalog.get_product!(image.product_id)

    html = conn |> get(~p"/products/#{product.slug}") |> html_response(200)
    assert html =~ "/uploads/images/#{image.id}/large.webp"
  end
end
