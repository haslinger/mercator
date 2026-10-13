defmodule Mercator.Catalog.Validations.HasVariant do
  @moduledoc "A product can only be activated when it has at least one variant."
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    product_id = changeset.data.id

    exists? =
      Mercator.Catalog.Variant
      |> Ash.Query.filter(product_id == ^product_id)
      |> Ash.exists?(authorize?: false)

    if exists? do
      :ok
    else
      {:error,
       field: :state, message: dgettext_noop("errors", "a product needs at least one variant")}
    end
  end
end
