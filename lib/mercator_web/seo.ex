defmodule MercatorWeb.Seo do
  @moduledoc """
  Search engine basics (#91): a meta description, a share image (Open
  Graph) and the canonical URL per page, set by the LiveViews with
  `assign_meta/2` and rendered by `MercatorWeb.Layouts.seo_tags/1` in the
  root layout.
  """
  alias MercatorWeb.Markdown

  @max_description 160

  @doc """
  Sets `@meta`: `description` (Markdown or text, shortened to about 160
  characters), `image` (a path or URL) and `canonical` (the path without
  filters or other query parameters).
  """
  def assign_meta(socket, opts) do
    meta = %{
      description: opts |> Keyword.get(:description) |> description(),
      image: opts[:image],
      canonical: opts[:canonical]
    }

    Phoenix.Component.assign(socket, :meta, meta)
  end

  @doc "Plain text of Markdown, cut at a word near 160 characters."
  def description(nil), do: nil

  def description(markdown) do
    case Markdown.to_text(markdown) do
      "" -> nil
      text when byte_size(text) <= @max_description -> text
      text -> shorten(text)
    end
  end

  defp shorten(text) do
    cut = String.slice(text, 0, @max_description)

    case String.split(cut, " ") do
      [_single] -> cut <> "…"
      words -> (words |> Enum.drop(-1) |> Enum.join(" ")) <> " …"
    end
  end

  @doc "An absolute URL of a path on this shop."
  def absolute(nil), do: nil
  def absolute("http" <> _ = url), do: url
  def absolute(path), do: MercatorWeb.Endpoint.url() <> path
end
