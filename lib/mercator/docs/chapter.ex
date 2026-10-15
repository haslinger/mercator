defmodule Mercator.Docs.Chapter do
  @moduledoc """
  One chapter of the documentation (docs/documentation-design.md): a
  Markdown file rendered at compile time, in one language.

    * `part` – `:manual`, `:operating`, `:developers`, `:help` or `:making_of`
    * `slug` – the file name without `.md`, unique within a part
    * `roles` – for the manual: who it is for (empty: all staff)
    * `pages` – admin pages whose "?" opens this chapter, e.g. `"admin/orders"`
    * `toc` – the headings below the title, `{level, id, text}`
    * `text` – plain text for the search
  """

  @enforce_keys [:part, :slug, :locale, :title, :html]
  defstruct [
    :part,
    :slug,
    :locale,
    :title,
    :html,
    :source,
    order: 100,
    roles: [],
    pages: [],
    toc: [],
    text: ""
  ]

  @type t :: %__MODULE__{}
end
