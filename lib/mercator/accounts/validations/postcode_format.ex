defmodule Mercator.Accounts.Validations.PostcodeFormat do
  @moduledoc "The postcode must match the country's format (e.g. 4 digits in Austria)."
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    country = Ash.Changeset.get_attribute(changeset, :country)
    postcode = Ash.Changeset.get_attribute(changeset, :postcode)

    case Mercator.Countries.postcode_format(country) do
      nil -> :ok
      format -> if postcode && postcode =~ format, do: :ok, else: error()
    end
  end

  defp error do
    {:error,
     field: :postcode,
     message: dgettext_noop("errors", "is not a valid postcode for this country")}
  end
end
