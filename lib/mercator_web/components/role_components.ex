defmodule MercatorWeb.RoleComponents do
  @moduledoc """
  Labels and badges for staff roles.
  """
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext

  @doc "The translated name of a role."
  def role_label(:administrator), do: gettext("Administrator")
  def role_label(:sales), do: gettext("Sales")
  def role_label(:sales_manager), do: gettext("Sales manager")
  def role_label(:contentmanager), do: gettext("Content manager")
  def role_label(:productmanager), do: gettext("Product manager")

  attr :roles, :list, required: true

  @doc "The roles of a user as badges."
  def role_badges(assigns) do
    ~H"""
    <span :for={role <- @roles} class="badge badge-outline badge-sm mr-1">{role_label(role)}</span>
    """
  end
end
