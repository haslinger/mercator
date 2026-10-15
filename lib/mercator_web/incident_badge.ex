defmodule MercatorWeb.IncidentBadge do
  @moduledoc """
  The number of open incidents in the admin sidebar (#105), live: an
  `on_mount` hook of the authenticated live session that assigns
  `@open_incidents` on admin pages for the roles that see incidents, and
  updates it when incidents change (`Mercator.Operations.Incidents`); the
  incident pages get `:incidents_changed` as well.
  Elsewhere `@open_incidents` is nil.
  """
  import Phoenix.Component, only: [assign: 3]

  alias Mercator.Operations.Incidents

  @roles [:administrator, :sales, :sales_manager]
  @incident_views [MercatorWeb.Admin.IncidentIndexLive, MercatorWeb.Admin.IncidentLive]

  def on_mount(:default, _params, _session, socket) do
    if admin_view?(socket.view) and sees_incidents?(socket.assigns[:current_user]) do
      if Phoenix.LiveView.connected?(socket), do: Incidents.subscribe()

      {:cont,
       socket
       |> assign(:open_incidents, Incidents.open_count(socket.assigns.current_user))
       |> Phoenix.LiveView.attach_hook(:incident_badge, :handle_info, &handle_info/2)}
    else
      {:cont, assign(socket, :open_incidents, nil)}
    end
  end

  # the incident pages update their lists too; other pages only the badge
  defp handle_info(:incidents_changed, socket) do
    socket = assign(socket, :open_incidents, Incidents.open_count(socket.assigns.current_user))
    if socket.view in @incident_views, do: {:cont, socket}, else: {:halt, socket}
  end

  defp handle_info(_message, socket), do: {:cont, socket}

  defp admin_view?(view), do: String.starts_with?(inspect(view), "MercatorWeb.Admin.")

  defp sees_incidents?(%{roles: roles}) when is_list(roles), do: Enum.any?(roles, &(&1 in @roles))
  defp sees_incidents?(_user), do: false
end
