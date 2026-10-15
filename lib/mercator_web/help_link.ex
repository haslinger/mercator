defmodule MercatorWeb.HelpLink do
  @moduledoc """
  The "?" of the admin pages (#124, docs/documentation-design.md): an
  `on_mount` hook of the authenticated live session that finds the
  documentation chapter for the page's route, e.g. `"admin/orders/:number"`
  (named in the chapter's front matter under `pages`), and assigns it as
  `@help_chapter`. `Layouts.admin` shows the "?" when there is one.
  Elsewhere `@help_chapter` is nil.
  """
  import Phoenix.Component, only: [assign: 3]

  alias Mercator.Docs

  def on_mount(:default, _params, _session, socket) do
    socket = assign(socket, :help_chapter, nil)

    if String.starts_with?(inspect(socket.view), "MercatorWeb.Admin.") do
      {:cont, Phoenix.LiveView.attach_hook(socket, :help_link, :handle_params, &handle_params/3)}
    else
      {:cont, socket}
    end
  end

  defp handle_params(_params, uri, socket) do
    chapter =
      case Phoenix.Router.route_info(MercatorWeb.Router, "GET", URI.parse(uri).path, nil) do
        %{route: route} ->
          Docs.for_page(page(route), socket.assigns[:locale], socket.assigns[:current_user])

        :error ->
          nil
      end

    {:cont, assign(socket, :help_chapter, chapter)}
  end

  @doc ~S"""
  The page key of a route, as chapters name it.

      iex> MercatorWeb.HelpLink.page("/admin/orders/:number")
      "admin/orders/:number"
  """
  def page(route), do: String.trim_leading(route, "/")
end
