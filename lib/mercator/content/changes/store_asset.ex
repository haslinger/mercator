defmodule Mercator.Content.Changes.StoreAsset do
  @moduledoc """
  Stores the uploaded file of an asset before the record is written: images
  (detected by content, not by name) become WebP in the media library's
  sizes, PDFs are copied. Other files are rejected.
  """
  use Ash.Resource.Change
  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Catalog.{ImageProcessing, Slug}
  alias Mercator.Uploads

  @sizes [wide: {1920, 80}, large: {1024, 82}, thumb: {400, 78}]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      id = Ash.Changeset.get_attribute(changeset, :id) || Ash.UUID.generate()
      source = Ash.Changeset.get_argument(changeset, :source_path)
      name = Ash.Changeset.get_attribute(changeset, :original_filename) || "file"
      changeset = Ash.Changeset.force_change_attribute(changeset, :id, id)

      if pdf?(source),
        do: store_document(changeset, source, id, name),
        else: store_image(changeset, source, id)
    end)
  end

  defp pdf?(source) do
    case File.open(source, [:read, :binary], &IO.binread(&1, 5)) do
      {:ok, "%PDF-"} -> true
      _ -> false
    end
  end

  defp store_image(changeset, source, id) do
    case ImageProcessing.process(source, Uploads.path("assets/#{id}"), @sizes) do
      {:ok, %{width: width, height: height}} ->
        Ash.Changeset.force_change_attributes(changeset,
          kind: :image,
          content_type: "image/webp",
          width: width,
          height: height,
          byte_size: File.stat!(source).size
        )

      {:error, _reason} ->
        Uploads.delete_dir("assets/#{id}")

        Ash.Changeset.add_error(changeset,
          field: :source_path,
          message: dgettext_noop("errors", "is neither an image nor a PDF")
        )
    end
  end

  defp store_document(changeset, source, id, name) do
    file_name = safe_name(name)
    dir = Uploads.path("assets/#{id}")
    File.mkdir_p!(dir)
    File.cp!(source, Path.join(dir, file_name))

    Ash.Changeset.force_change_attributes(changeset,
      kind: :document,
      file_name: file_name,
      content_type: "application/pdf",
      byte_size: File.stat!(source).size
    )
  end

  # keeps the name readable for downloads, without path parts or odd characters
  defp safe_name(name) do
    base = name |> Path.basename() |> Path.rootname() |> Slug.slugify()
    if(base in [nil, ""], do: "document", else: base) <> ".pdf"
  end
end
