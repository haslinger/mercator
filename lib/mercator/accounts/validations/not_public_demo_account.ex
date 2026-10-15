defmodule Mercator.Accounts.Validations.NotPublicDemoAccount do
  @moduledoc """
  The public demo accounts cannot be changed in demo mode (#46, password and
  roles), so every visitor finds them as documented on the sign-in page.
  Option `:field`: the field the error is shown at.
  """
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, opts, _context) do
    if Mercator.Demo.public_account?(changeset.data),
      do:
        {:error,
         field: opts[:field], message: dgettext_noop("errors", "demo accounts cannot be changed")},
      else: :ok
  end
end
