defmodule Mercator.Accounts.Checks.ActorHasRole do
  @moduledoc """
  Policy check: the actor holds the given role.

      authorize_if {Mercator.Accounts.Checks.ActorHasRole, role: :administrator}
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(opts), do: "actor has role #{inspect(opts[:role])}"

  @impl true
  def match?(%{roles: roles}, _context, opts) when is_list(roles) do
    opts[:role] in roles
  end

  def match?(_actor, _context, _opts), do: false
end
