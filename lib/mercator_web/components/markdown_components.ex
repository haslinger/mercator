defmodule MercatorWeb.MarkdownComponents do
  @moduledoc """
  Showing and editing Markdown content (#13, #78).
  """
  use Phoenix.Component

  alias MercatorWeb.Markdown

  attr :text, :string, default: nil, doc: "Markdown"
  attr :heading_offset, :integer, default: 0
  attr :class, :any, default: nil
  attr :rest, :global

  @doc """
  Renders Markdown as HTML, styled by the `.markdown` rules in app.css.

      <.markdown text={Translated.t(@product.long_description, @locale)} />
  """
  def markdown(assigns) do
    ~H"""
    <div :if={@text not in [nil, ""]} class={["markdown", @class]} {@rest}>
      {Phoenix.HTML.raw(Markdown.to_html(@text, heading_offset: @heading_offset))}
    </div>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :label, :string, required: true
  attr :placeholder, :string, default: nil
  attr :min_height, :string, default: "160px"

  @doc """
  A Markdown editor (OverType, see assets/js/hooks/markdown_editor.js) for
  one form value; a plain textarea without JavaScript.
  """
  def markdown_input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label class="label mb-1" for={@id}>{@label}</label>
      <div id={"#{@id}-editor"} class="markdown-editor" phx-hook="MarkdownEditor" phx-update="ignore">
        <textarea
          id={@id}
          name={@name}
          rows="8"
          class="textarea w-full"
          placeholder={@placeholder}
          data-min-height={@min_height}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </div>
    </div>
    """
  end
end
