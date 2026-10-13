defmodule MercatorWeb.Navigation do
  @moduledoc """
  Loads the top-level categories for the main navigation, as a plug for
  controller pages and an `on_mount` hook for LiveViews (`@nav_categories`).
  """
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts), do: Plug.Conn.assign(conn, :nav_categories, categories())

  def on_mount(:default, _params, _session, socket) do
    {:cont, Phoenix.Component.assign_new(socket, :nav_categories, &categories/0)}
  end

  # hidden categories are reachable by link but not listed (#52)
  defp categories do
    Enum.filter(Mercator.Catalog.list_root_categories!(), &(&1.state == :active))
  end
end
