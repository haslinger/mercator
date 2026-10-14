defmodule Mercator.Consulting.Validations.CallbackContact do
  @moduledoc "A callback contact (#95) is a plausible email address or phone number."
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def validate(changeset, _opts, _context) do
    contact = Ash.Changeset.get_attribute(changeset, :callback_contact) || ""

    case Ash.Changeset.get_attribute(changeset, :callback_kind) do
      :email ->
        if contact =~ ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
          do: :ok,
          else:
            {:error,
             field: :callback_contact,
             message: dgettext_noop("errors", "is not a valid email address")}

      :phone ->
        if String.replace(contact, ~r/[^\d]/, "") |> String.length() >= 6 and
             contact =~ ~r/^[\d\s+()\/.-]+$/,
           do: :ok,
           else:
             {:error,
              field: :callback_contact,
              message: dgettext_noop("errors", "is not a valid phone number")}

      _ ->
        :ok
    end
  end
end
