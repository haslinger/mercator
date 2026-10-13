defmodule Mercator.Catalog.Validations.ExactlyOneOwner do
  @moduledoc "An image belongs either to a product or to a category."
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    owners =
      Enum.count(
        [:product_id, :category_id],
        &(not is_nil(Ash.Changeset.get_attribute(changeset, &1)))
      )

    if owners == 1,
      do: :ok,
      else:
        {:error,
         field: :product_id,
         message: dgettext_noop("errors", "an image belongs to exactly one product or category")}
  end
end
