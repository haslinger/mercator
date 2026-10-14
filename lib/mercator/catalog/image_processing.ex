defmodule Mercator.Catalog.ImageProcessing do
  @moduledoc """
  Converts an uploaded image into the sizes the shop uses, as WebP (libvips
  via the `image` library, decision #60):

    * `large.webp` – longest edge 1024 px, for the product page
    * `thumb.webp` – longest edge 400 px, for tiles and cards
  """

  @sizes [large: {1024, 82}, thumb: {400, 78}]

  @doc "The size names."
  def sizes, do: Keyword.keys(@sizes)

  @doc """
  Reads `source`, writes all sizes into `dest_dir` and returns the
  dimensions of the original: `{:ok, %{width: w, height: h}}` or
  `{:error, reason}` if the file is not a readable image. `sizes` is a
  keyword list `name: {max_pixels, quality}`, by default the shop's sizes.
  """
  def process(source, dest_dir, sizes \\ @sizes) do
    with {:ok, image} <- Image.open(source),
         :ok <- File.mkdir_p(dest_dir),
         :ok <- write_sizes(image, dest_dir, sizes) do
      {:ok, %{width: Image.width(image), height: Image.height(image)}}
    end
  end

  defp write_sizes(image, dest_dir, sizes) do
    Enum.reduce_while(sizes, :ok, fn {name, {max, quality}}, :ok ->
      with {:ok, resized} <- Image.thumbnail(image, max),
           {:ok, _} <- Image.write(resized, Path.join(dest_dir, "#{name}.webp"), quality: quality) do
        {:cont, :ok}
      else
        error -> {:halt, error}
      end
    end)
  end
end
