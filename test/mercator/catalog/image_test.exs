defmodule Mercator.Catalog.ImageTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Catalog
  alias Mercator.Catalog.Image
  alias Mercator.Uploads

  @jpg "test/fixtures/wood.jpg"

  defp upload(attrs, opts \\ [authorize?: false]) do
    attrs |> Map.put_new(:source_path, @jpg) |> Catalog.upload_image(opts)
  end

  test "uploading converts the file into WebP sizes and stores the dimensions" do
    product = product_fixture()

    assert {:ok, image} = upload(%{product_id: product.id, original_filename: "wood.jpg"})
    assert {image.width, image.height} == {600, 400}

    for size <- [:large, :thumb] do
      file = Uploads.path("images/#{image.id}/#{size}.webp")
      assert File.regular?(file)
      assert {:ok, webp} = Elixir.Image.open(file)

      assert max(Elixir.Image.width(webp), Elixir.Image.height(webp)) <=
               if(size == :thumb, do: 400, else: 1024)
    end

    assert Image.url(image, :thumb) == "/uploads/images/#{image.id}/thumb.webp"
  end

  test "rejects files that are not images and leaves no files behind" do
    product = product_fixture()

    assert {:error, %Ash.Error.Invalid{}} =
             upload(%{product_id: product.id, source_path: "test/fixtures/not_an_image.txt"})
  end

  test "an image belongs to exactly one product or category" do
    assert {:error, %Ash.Error.Invalid{}} = upload(%{})

    assert {:error, %Ash.Error.Invalid{}} =
             upload(%{product_id: product_fixture().id, category_id: category_fixture().id})
  end

  test "deleting an image removes its files" do
    {:ok, image} = upload(%{category_id: category_fixture().id})
    dir = Uploads.path("images/#{image.id}")
    assert File.dir?(dir)

    Catalog.destroy_image!(image, authorize?: false)
    refute File.exists?(dir)
  end

  test "images of invisible products are hidden, product managers upload" do
    draft = product_fixture(state: :draft)
    {:ok, _} = upload(%{product_id: draft.id})

    assert Ash.read!(Image) == []

    assert {:error, %Ash.Error.Forbidden{}} =
             upload(%{product_id: draft.id}, actor: user_fixture())

    assert {:ok, _} =
             upload(%{product_id: draft.id}, actor: user_fixture(roles: [:productmanager]))
  end

  test "images are loaded in their order" do
    product = product_fixture()
    {:ok, second} = upload(%{product_id: product.id, position: 2})
    {:ok, first} = upload(%{product_id: product.id, position: 1})

    assert Enum.map(Ash.load!(product, :images).images, & &1.id) == [first.id, second.id]
  end
end
