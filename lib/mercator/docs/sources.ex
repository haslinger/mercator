defmodule Mercator.Docs.Sources do
  @moduledoc """
  Where the documentation comes from (docs/documentation-design.md,
  section 2) and where each part is shown. A module of its own, because
  `Mercator.Docs` needs it while it is being compiled.
  """

  alias Mercator.Docs.Chapter

  @root Path.expand("../../..", __DIR__)

  @paths %{
    manual: "/admin/help/manual",
    operating: "/admin/help/operating",
    developers: "/admin/help/developers",
    help: "/help",
    making_of: "/making-of"
  }

  # the order of the developer documents, which have no front matter
  @design_order ~w(roadmap-history roadmap-future catalog-design checkout-design cms-design
                   guided-selling-design payment-design deployment-design documentation-design)

  @doc "The URL path where a part is shown."
  def path(part), do: Map.fetch!(@paths, part)

  @doc "The URL of a chapter."
  def link({part, slug}), do: "#{path(part)}/#{slug}"

  @doc "All source files as `{part, locale, path}`."
  def all do
    priv_root = Path.join(@root, "priv/docs")

    priv =
      for path <- Path.wildcard(Path.join(priv_root, "*/*/*.md")) do
        [locale, folder | _] = path |> Path.relative_to(priv_root) |> Path.split()
        {part(folder), locale, path}
      end

    docs =
      for pattern <- ["docs/*-design.md", "docs/roadmap-*.md"],
          path <- Path.wildcard(Path.join(@root, pattern)),
          do: {:developers, "en", path}

    sessions =
      for path <- Path.wildcard(Path.join(@root, "docs/sessions/20*.md")),
          do: {:making_of, "en", path}

    priv ++ docs ++ [{:making_of, "en", Path.join(@root, "docs/metrics.md")}] ++ sessions
  end

  defp part("manual"), do: :manual
  defp part("operating"), do: :operating
  defp part("developers"), do: :developers
  defp part("help"), do: :help
  defp part("making-of"), do: :making_of

  @doc """
  Order and title for the files that have no front matter. Sessions get no
  table of contents: every message is a heading there.
  """
  def place(%Chapter{part: :developers, order: 100, slug: slug} = chapter) do
    case Enum.find_index(@design_order, &(&1 == slug)) do
      nil -> %{chapter | order: 90}
      index -> %{chapter | order: 10 + index}
    end
  end

  def place(%Chapter{part: :making_of, slug: "metrics"} = chapter), do: %{chapter | order: 10}

  def place(
        %Chapter{part: :making_of, slug: <<date::binary-size(10), "-", id::binary>>} = chapter
      )
      when binary_part(date, 0, 2) == "20",
      do: %{chapter | order: 20, title: "Session #{date} (#{id})", toc: []}

  def place(chapter), do: chapter
end
