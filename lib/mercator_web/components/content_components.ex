defmodule MercatorWeb.ContentComponents do
  @moduledoc """
  Rendering of CMS blocks (docs/cms-design.md, section 3). Each block type
  of `Mercator.Content.Block` has one clause of `block/1`.
  """
  use Phoenix.Component

  import MercatorWeb.MarkdownComponents, only: [markdown: 1]

  alias Mercator.Content.Blocks
  alias Mercator.Translated

  attr :block, Ash.Union, required: true
  attr :locale, :string, required: true

  def block(%{block: %Ash.Union{value: %Blocks.Text{} = text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <section class="block-text" id={"block-#{@text.id}"}>
      <.markdown text={Translated.t(@text.text, @locale)} class="max-w-3xl" />
    </section>
    """
  end
end
