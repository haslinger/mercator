defmodule Mercator.Catalog.Changes.SetSlug do
  @moduledoc """
  Sets the `slug` from the default-locale translation of a translated
  attribute (option `from`, default `:name`) when no slug was given.
  """
  use Ash.Resource.Change

  alias Mercator.Catalog.Slug
  alias Mercator.Translated

  @impl true
  def change(changeset, opts, _context) do
    from = opts[:from] || :name

    case Ash.Changeset.get_attribute(changeset, :slug) do
      slug when is_binary(slug) and slug != "" ->
        Ash.Changeset.force_change_attribute(changeset, :slug, Slug.slugify(slug))

      _ ->
        translated = Ash.Changeset.get_attribute(changeset, from)
        source = Translated.t(translated, Translated.default_locale())
        Ash.Changeset.force_change_attribute(changeset, :slug, Slug.slugify(source))
    end
  end
end
