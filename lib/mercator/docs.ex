defmodule Mercator.Docs do
  @moduledoc """
  The documentation, compiled into the app (phase 9,
  docs/documentation-design.md): every deployment shows exactly the
  documentation of the code it runs.

  | Part | Source | Who |
  |---|---|---|
  | `:manual` | `priv/docs/<locale>/manual/` | staff, by the chapter's `roles` |
  | `:operating` | `priv/docs/<locale>/operating/` | administrators |
  | `:developers` | `priv/docs/en/developers/`, `docs/*-design.md`, `docs/roadmap-*.md` | administrators |
  | `:help` | `priv/docs/<locale>/help/` | everybody (`/help`) |
  | `:making_of` | `priv/docs/en/making-of/`, `docs/metrics.md`, `docs/sessions/` | everybody, if enabled |

  The files are read at compile time; editing, adding or removing one
  recompiles this module. Chapters are shown in the user's language, else
  German, else whatever language they exist in (#123, #133).
  """

  alias Mercator.Docs.{Chapter, Loader, Sources}

  @parts [:manual, :operating, :developers, :help, :making_of]
  @staff_roles [:administrator, :sales, :sales_manager, :contentmanager, :productmanager]
  @fallback_locales ["de", "en"]

  @sources Sources.all()
  @source_paths Enum.map(@sources, &elem(&1, 2))
  for path <- @source_paths, do: @external_resource(path)

  @chapters @sources |> Loader.load(&Sources.link/1) |> Enum.map(&Sources.place/1)

  @doc false
  # a new or deleted source file recompiles the module, too
  def __mix_recompile__?, do: Enum.map(Sources.all(), &elem(&1, 2)) != @source_paths

  @doc "The parts of the documentation."
  def parts, do: @parts

  @doc "The URL path where a part is shown."
  defdelegate path(part), to: Sources

  @doc "The URL of a chapter."
  def link(%Chapter{part: part, slug: slug}), do: Sources.link({part, slug})

  @doc """
  The chapters of a part the actor may see, in `locale` (with fallback),
  in their order.
  """
  def chapters(part, locale, actor) do
    @chapters
    |> Enum.filter(&(&1.part == part and visible?(&1, actor)))
    |> in_locale(locale)
    |> Enum.sort_by(&{&1.order, &1.slug})
  end

  @doc "One chapter, or `:error` when it does not exist or the actor may not see it."
  def chapter(part, slug, locale, actor) do
    case Enum.find(chapters(part, locale, actor), &(&1.slug == slug)) do
      nil -> :error
      chapter -> {:ok, chapter}
    end
  end

  @doc """
  The chapter for an admin page's "?" (`page` as in the front matter, e.g.
  `"admin/orders"`), or nil.
  """
  def for_page(page, locale, actor) do
    @parts
    |> Enum.flat_map(&chapters(&1, locale, actor))
    |> Enum.find(&(page in &1.pages))
  end

  @doc "All pages that some chapter claims for its \"?\" (for the tests)."
  def pages, do: @chapters |> Enum.flat_map(& &1.pages) |> Enum.uniq()

  @doc """
  Searches the parts the actor may see. Returns `{chapter, snippet}`,
  chapters whose title matches first.
  """
  def search(query, locale, actor, parts \\ @parts) do
    case String.trim(query || "") do
      "" ->
        []

      query ->
        needle = String.downcase(query)

        parts
        |> Enum.flat_map(&chapters(&1, locale, actor))
        |> Enum.filter(
          &(String.contains?(String.downcase(&1.title), needle) or match(&1, needle))
        )
        |> Enum.sort_by(&(not String.contains?(String.downcase(&1.title), needle)))
        |> Enum.map(&{&1, snippet(&1.text, needle)})
    end
  end

  defp match(chapter, needle), do: String.contains?(String.downcase(chapter.text), needle)

  # about 160 characters around the first hit
  defp snippet(text, needle) do
    case :binary.match(String.downcase(text), needle) do
      {position, _length} ->
        start = max(position - 60, 0)
        prefix = if start > 0, do: "…", else: ""
        piece = binary_part(text, start, min(160, byte_size(text) - start))
        prefix <> String.trim(String.replace_invalid(piece)) <> "…"

      :nomatch ->
        String.slice(text, 0, 160)
    end
  end

  @doc "Whether the actor may see a chapter (#124, #125)."
  def visible?(%Chapter{part: part}, _actor) when part in [:help, :making_of], do: true
  def visible?(_chapter, nil), do: false

  def visible?(%Chapter{part: part, roles: roles}, actor) do
    actor_roles = actor.roles || []

    cond do
      :administrator in actor_roles -> true
      part in [:operating, :developers] -> false
      not Enum.any?(actor_roles, &(&1 in @staff_roles)) -> false
      roles == [] -> true
      true -> Enum.any?(roles, &(&1 in actor_roles))
    end
  end

  # one chapter per slug: the user's language, else German, else any
  defp in_locale(chapters, locale) do
    preference = Enum.uniq([to_string(locale) | @fallback_locales])

    chapters
    |> Enum.group_by(& &1.slug)
    |> Enum.map(fn {_slug, versions} ->
      Enum.min_by(versions, fn chapter ->
        Enum.find_index(preference, &(&1 == chapter.locale)) || length(preference)
      end)
    end)
  end
end
