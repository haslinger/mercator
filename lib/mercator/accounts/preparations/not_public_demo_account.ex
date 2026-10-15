defmodule Mercator.Accounts.Preparations.NotPublicDemoAccount do
  @moduledoc """
  No password reset for the public demo accounts in demo mode (#46): their
  password is published and must stay as it is.
  """
  use Ash.Resource.Preparation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def supports(_opts), do: [Ash.ActionInput]

  @impl true
  def prepare(input, _opts, _context) do
    if Mercator.Demo.public_account?(Ash.ActionInput.get_argument(input, :email)),
      do:
        Ash.ActionInput.add_error(input,
          field: :email,
          message: dgettext_noop("errors", "demo accounts cannot be changed")
        ),
      else: input
  end
end
