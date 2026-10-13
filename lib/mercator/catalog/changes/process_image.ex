defmodule Mercator.Catalog.Changes.ProcessImage do
  @moduledoc """
  Processes the file given in the `source_path` argument into the image's
  storage directory before the record is written, and stores its dimensions.
  A file that is not a readable image is rejected.
  """
  use Ash.Resource.Change
  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Catalog.ImageProcessing
  alias Mercator.Uploads

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      id = Ash.Changeset.get_attribute(changeset, :id) || Ash.UUID.generate()
      source = Ash.Changeset.get_argument(changeset, :source_path)

      case ImageProcessing.process(source, Uploads.path("images/#{id}")) do
        {:ok, %{width: width, height: height}} ->
          changeset
          |> Ash.Changeset.force_change_attribute(:id, id)
          |> Ash.Changeset.force_change_attribute(:width, width)
          |> Ash.Changeset.force_change_attribute(:height, height)

        {:error, _reason} ->
          Uploads.delete_dir("images/#{id}")

          Ash.Changeset.add_error(changeset,
            field: :source_path,
            message: dgettext_noop("errors", "is not a readable image")
          )
      end
    end)
  end
end
