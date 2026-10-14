defmodule MercatorWeb.MarkdownTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]

  alias MercatorWeb.Markdown
  alias MercatorWeb.MarkdownComponents

  doctest MercatorWeb.Markdown

  describe "to_html/2" do
    test "renders headings, lists, tables and line breaks" do
      html =
        Markdown.to_html(
          "## Pflege\nZeile 1\nZeile 2\n\n- geölt\n- gebürstet\n\n| a | b |\n|---|---|\n| 1 | 2 |"
        )

      assert html =~ "<h2>Pflege</h2>"
      assert html =~ "Zeile 1<br>"
      assert html =~ "<li>geölt</li>"
      assert html =~ "<td>1</td>"
    end

    test "escapes raw HTML and drops unsafe links" do
      html = Markdown.to_html("Text <img src=x onerror=alert(1)> [klick](javascript:alert(1))")

      refute html =~ "<img"
      assert html =~ "&lt;img"
      refute html =~ "javascript:"
    end

    test "nil gives an empty string" do
      assert Markdown.to_html(nil) == ""
    end
  end

  describe "markdown/1" do
    test "renders nothing for empty text" do
      assigns = %{}
      assert rendered_to_string(~H|<MarkdownComponents.markdown text={nil} />|) == ""
    end

    test "wraps the HTML in a .markdown container" do
      assigns = %{}
      html = rendered_to_string(~H|<MarkdownComponents.markdown text="**fett**" id="t" />|)
      assert html =~ ~s(class="markdown)
      assert html =~ "<strong>fett</strong>"
    end
  end
end
