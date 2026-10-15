defmodule MercatorWeb.DocsComponents do
  @moduledoc """
  Pieces of the documentation pages (`/admin/help`, `/help`, the
  making-of): a chapter's HTML and its table of contents. The HTML comes
  from `Mercator.Docs`, rendered at compile time from the repository's own
  Markdown with raw HTML escaped, so it is shown as it is; this is the only
  place that does so.
  """
  use Phoenix.Component

  use Gettext, backend: MercatorWeb.Gettext

  attr :chapter, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "The chapter's text, styled by the `.markdown` rules in app.css."
  def chapter_html(assigns) do
    ~H"""
    <div class={["markdown", @class]} {@rest}>{Phoenix.HTML.raw(@chapter.html)}</div>
    """
  end

  attr :chapter, :map, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "The chapter's table of contents (headings level 2 and 3), if it has one."
  def chapter_toc(assigns) do
    ~H"""
    <nav :if={@chapter.toc != []} class={["space-y-1", @class]} {@rest}>
      <p class="menu-title px-0">{gettext("Contents")}</p>
      <a
        :for={{level, id, text} <- @chapter.toc}
        href={"#" <> id}
        class={["link link-hover block text-sm", level == 3 && "pl-3"]}
      >
        {Phoenix.HTML.raw(text)}
      </a>
    </nav>
    """
  end
end
