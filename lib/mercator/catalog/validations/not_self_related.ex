defmodule Mercator.Catalog.Validations.NotSelfRelated do
  @moduledoc "A product cannot be related to itself."
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :product_id) ==
         Ash.Changeset.get_attribute(changeset, :related_product_id) do
      {:error,
       field: :related_product_id,
       message: dgettext_noop("errors", "a product cannot be related to itself")}
    else
      :ok
    end
  end
end
