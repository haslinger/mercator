defmodule Mercator.Accounts.Validations.KeepOwnAdminRole do
  @moduledoc """
  Administrators cannot remove the administrator role from themselves.

  This prevents locking everybody out of user administration by accident.
  """
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, %{actor: %{id: actor_id}}) do
    removes_own_admin_role? =
      changeset.data.id == actor_id and
        :administrator in changeset.data.roles and
        :administrator not in (Ash.Changeset.get_attribute(changeset, :roles) || [])

    if removes_own_admin_role? do
      {:error,
       field: :roles,
       message: dgettext_noop("errors", "you cannot remove your own administrator role")}
    else
      :ok
    end
  end

  def validate(_changeset, _opts, _context), do: :ok
end
