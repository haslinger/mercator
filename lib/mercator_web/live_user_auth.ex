defmodule MercatorWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use MercatorWeb, :verified_routes
  use Gettext, backend: MercatorWeb.Gettext

  import Phoenix.Component

  alias AshAuthentication.Phoenix.LiveSession
  alias Mercator.Accounts.Role

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {MercatorWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Requires a signed-in user with any staff role (the admin area, #16)
  def on_mount(:require_staff, params, session, socket) do
    on_mount({:require_any_role, Role.values()}, params, session, socket)
  end

  def on_mount({:require_any_role, roles}, _params, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      user ->
        if Enum.any?(roles, &(&1 in user.roles)), do: {:cont, socket}, else: forbidden(socket)
    end
  end

  # Requires a signed-in user holding the given staff role, e.g.
  # on_mount {MercatorWeb.LiveUserAuth, {:require_role, :administrator}}
  def on_mount({:require_role, role}, _params, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      %{roles: roles} = _user ->
        if role in roles, do: {:cont, socket}, else: forbidden(socket)
    end
  end

  # A signed-in user without a name (signed up by magic link) enters it
  # first (#102); everything else in the live session waits. The chat panel
  # (rendered inside every page) is left alone; the page redirects.
  def on_mount(:require_name, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %{name: nil} when socket.view not in [MercatorWeb.NameLive, MercatorWeb.ChatLive] ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/account/name")}

      _user_with_name_or_nobody ->
        {:cont, socket}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  @doc "`path` if it is a path within the shop (no other host), else `/`."
  def local_path("/" <> rest = path) do
    if String.starts_with?(rest, ["/", "\\"]), do: "/", else: path
  end

  def local_path(_path), do: "/"

  defp forbidden(socket) do
    {:halt,
     socket
     |> Phoenix.LiveView.put_flash(:error, gettext("You are not allowed to access this page."))
     |> Phoenix.LiveView.redirect(to: ~p"/")}
  end
end
