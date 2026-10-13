defmodule Mercator.Seeds.ImagesTest do
  use Mercator.DataCase, async: true

  import Mercator.CatalogFixtures

  alias Mercator.Seeds.Images

  setup do
    dir = Path.join(System.tmp_dir!(), "mercator-import-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "categories"))
    File.mkdir_p!(Path.join(dir, "products"))
    on_exit(fn -> File.rm_rf!(dir) end)

    category = category_fixture(slug: "bauholz")
    product = product_fixture(number: "BH-KVH-FI")

    File.cp!("test/fixtures/wood.jpg", Path.join(dir, "categories/bauholz.jpeg"))
    # extension-less files are detected by their content
    File.cp!("test/fixtures/wood.jpg", Path.join(dir, "products/BH-KVH-FI"))
    File.cp!("test/fixtures/wood.jpg", Path.join(dir, "products/BH-UNKNOWN.jpeg"))
    # file names are matched case-insensitively against article numbers
    product_fixture(number: "BH-PLUSHIE")
    File.cp!("test/fixtures/wood.jpg", Path.join(dir, "products/BH-plushie.jpeg"))

    %{dir: dir, category: category, product: product}
  end

  test "assigns images by category slug and article number", %{
    dir: dir,
    category: category,
    product: product
  } do
    assert %{imported: 3, skipped: 0, unknown: ["products/BH-UNKNOWN.jpeg"]} = Images.import(dir)

    assert [%{original_filename: "bauholz.jpeg"}] = Ash.load!(category, :images).images
    assert [%{original_filename: "BH-KVH-FI"} = image] = Ash.load!(product, :images).images
    assert image.alt["de"] == product.title["de"]
  end

  test "can run repeatedly", %{dir: dir} do
    Images.import(dir)

    assert %{imported: 0, skipped: 3} = Images.import(dir)
  end
end
