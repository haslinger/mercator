defmodule Mercator.Content.PageContent do
  @moduledoc """
  The published content of a page (#90): title, SEO description and blocks
  as they were when the page was last published. The page's own attributes
  are the working copy.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :title, Mercator.Translated, allow_nil?: false, public?: true
    attribute :seo_description, Mercator.Translated, public?: true
    attribute :blocks, {:array, Mercator.Content.Block}, default: [], public?: true
  end
end
