defmodule MercatorWeb.Markdown do
  @moduledoc """
  Markdown for content texts (#13, #77): CommonMark with tables,
  strikethrough and autolinks, rendered by MDEx.

  Content is not trusted blindly: raw HTML is escaped (shown as text),
  unsafe links such as `javascript:` are removed, and the result is
  sanitized once more. A single line break is a line break, as authors
  expect from a text field.
  """

  @options [
    extension: [strikethrough: true, table: true, autolink: true],
    render: [escape: true, hardbreaks: true],
    sanitize: MDEx.Document.default_sanitize_options()
  ]

  @doc """
  Renders Markdown to safe HTML. `heading_offset` shifts headings down,
  e.g. `1` turns `#` into `<h2>` on pages that already have an `<h1>`.

      iex> MercatorWeb.Markdown.to_html("**Lärche** <b>x</b>")
      "<p><strong>Lärche</strong> &lt;b&gt;x&lt;/b&gt;</p>"

      iex> MercatorWeb.Markdown.to_html("# Titel", heading_offset: 1)
      "<h2>Titel</h2>"
  """
  def to_html(text, opts \\ [])
  def to_html(nil, _opts), do: ""

  def to_html(text, opts) when is_binary(text) do
    text
    |> MDEx.parse_document!(@options)
    |> shift_headings(Keyword.get(opts, :heading_offset, 0))
    |> MDEx.to_html!(@options)
    |> String.trim()
  end

  defp shift_headings(document, 0), do: document

  defp shift_headings(document, offset) do
    MDEx.traverse_and_update(document, fn
      %MDEx.Heading{level: level} = heading -> %{heading | level: min(level + offset, 6)}
      node -> node
    end)
  end
end
