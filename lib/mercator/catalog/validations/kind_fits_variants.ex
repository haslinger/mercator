defmodule Mercator.Catalog.Validations.KindFitsVariants do
  @moduledoc """
  A product with more than one variant cannot become `simple` (#103): the
  other variants are deleted first, nothing is dropped silently.
  """
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    product_id = changeset.data.id

    if Ash.Changeset.get_attribute(changeset, :kind) == :simple and
         Mercator.Catalog.Variant
         |> Ash.Query.filter(product_id == ^product_id)
         |> Ash.count!(authorize?: false) > 1 do
      {:error,
       field: :kind,
       message:
         dgettext_noop("errors", "a simple product has one variant; delete the others first")}
    else
      :ok
    end
  end
end
