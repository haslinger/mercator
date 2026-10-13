defmodule Mercator.Seeds.Images do
  @moduledoc """
  Imports demo images from a directory (by default `assets/img/`):

    * `categories/<slug>.<ext>` → image of the category with that slug
    * `products/<article number>.<ext>` → image of the product with that number

  The extension doesn't matter (the format is detected from the content).
  Files whose category or product doesn't exist are reported and skipped;
  images that were already imported (same original file name for the same
  category or product) are skipped, so the import can run repeatedly.
  """

  alias Mercator.Catalog
  alias Mercator.Translated

  @doc "Imports all images below `dir`. Returns `%{imported: n, skipped: n, unknown: [file]}`."
  def import(dir \\ "assets/img") do
    results =
      for kind <- ["categories", "products"],
          file <- list(Path.join(dir, kind)) do
        import_file(kind, Path.join([dir, kind, file]), file)
      end

    %{
      imported: Enum.count(results, &(&1 == :imported)),
      skipped: Enum.count(results, &(&1 == :skipped)),
      unknown: for({:unknown, file} <- results, do: file)
    }
  end

  defp list(dir) do
    case File.ls(dir) do
      {:ok, files} -> files |> Enum.reject(&String.starts_with?(&1, ".")) |> Enum.sort()
      {:error, _} -> []
    end
  end

  defp import_file(kind, path, file) do
    name = file |> Path.rootname() |> Path.basename()

    case owner(kind, name) do
      nil -> {:unknown, Path.join(kind, file)}
      owner -> maybe_upload(owner, path, file)
    end
  end

  defp owner("categories", slug) do
    case Catalog.get_category_by_slug(slug, authorize?: false) do
      {:ok, category} -> {:category_id, category.id, category.name}
      {:error, _} -> nil
    end
  end

  # article numbers are upper case; file names may be written in any case
  defp owner("products", number) do
    case Catalog.get_product_by_number(String.upcase(number), authorize?: false) do
      {:ok, product} -> {:product_id, product.id, product.title}
      {:error, _} -> nil
    end
  end

  defp maybe_upload({field, id, name}, path, file) do
    exists? =
      Mercator.Catalog.Image
      |> Ash.Query.do_filter([{field, id}, original_filename: file])
      |> Ash.exists?(authorize?: false)

    if exists? do
      :skipped
    else
      Catalog.upload_image!(
        %{field => id, source_path: path, original_filename: file, alt: alt(name)},
        authorize?: false
      )

      :imported
    end
  end

  defp alt(name), do: Map.new(Translated.locales(), &{&1, Translated.t(name, &1)})
end
