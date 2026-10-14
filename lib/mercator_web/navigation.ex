defmodule MercatorWeb.Navigation do
  @moduledoc """
  Loads the navigation of the shop layout, as a plug for controller pages
  and an `on_mount` hook for LiveViews: `@nav` with

    * `categories` – the active top-level categories
    * `main` – published pages marked for the main navigation (#93)
    * `footer` – published pages marked for the footer

  Pages are shown with their published title.
  """
  @behaviour Plug

  alias Mercator.{Catalog, Content}

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts), do: Plug.Conn.assign(conn, :nav, load())

  def on_mount(:default, _params, _session, socket) do
    {:cont, Phoenix.Component.assign_new(socket, :nav, &load/0)}
  end

  @doc "The navigation map, see the module doc."
  def load do
    %{
      # hidden categories are reachable by link but not listed (#52)
      categories:
        Enum.filter(Catalog.list_root_categories!(load: :images), &(&1.state == :active)),
      main: Content.list_menu_pages!(:main),
      footer: Content.list_menu_pages!(:footer)
    }
  end

  @doc "An empty navigation, e.g. for pages rendered without the plug."
  def empty, do: %{categories: [], main: [], footer: []}
end
