defmodule Mercator.Uploads do
  @moduledoc """
  Local disk storage for uploaded files (decision #11). The root directory is
  configured with `config :mercator, :uploads_dir` (`UPLOADS_DIR` in
  production). Files are served under `/uploads/…` by
  `MercatorWeb.UploadController`.
  """

  @doc "The absolute root directory of all uploads."
  def root, do: Application.fetch_env!(:mercator, :uploads_dir)

  @doc "The absolute path of a file below the root."
  def path(relative), do: Path.join(root(), relative)

  @doc "The public URL of a file below the root."
  def url(relative), do: "/uploads/" <> relative

  @doc """
  Resolves a requested path (list of segments) to a file below the root.
  Rejects anything that could leave the root (`..`, absolute segments).
  """
  def resolve(segments) when is_list(segments) do
    if Enum.any?(segments, &(&1 in ["", ".", ".."] or String.contains?(&1, ["/", "\\", <<0>>]))) do
      :error
    else
      file = Path.join([root() | segments])
      if File.regular?(file), do: {:ok, file}, else: :error
    end
  end

  @doc "Deletes a directory below the root, e.g. all sizes of one image."
  def delete_dir(relative) do
    File.rm_rf(path(relative))
    :ok
  end
end
