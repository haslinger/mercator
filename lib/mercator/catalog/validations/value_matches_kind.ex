defmodule Mercator.Catalog.Validations.ValueMatchesKind do
  @moduledoc """
  A product property value must match its property's kind: exactly the text,
  number or boolean value is set (Rails: Value#data_meets_state).
  """
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    property_id = Ash.Changeset.get_attribute(changeset, :property_id)

    values = %{
      text: Ash.Changeset.get_attribute(changeset, :text_value),
      number: Ash.Changeset.get_attribute(changeset, :number_value),
      boolean: Ash.Changeset.get_attribute(changeset, :boolean_value)
    }

    with {:ok, property} <- Ash.get(Mercator.Catalog.Property, property_id, authorize?: false),
         [kind] <- for({kind, value} <- values, not is_nil(value), do: kind),
         true <- kind == property.kind do
      :ok
    else
      _ ->
        {:error,
         field: :property_id,
         message:
           dgettext_noop("errors", "exactly one value matching the property's kind is required")}
    end
  end
end
