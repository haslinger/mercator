defmodule MercatorWeb.Navigation do
  @moduledoc """
  Loads the navigation of the shop layout, as a plug for controller pages
  and an `on_mount` hook for LiveViews: `@nav` with

    * `categories` – the active top-level categories
    * `main` – published pages marked for the main navigation (#93)
    * `footer` – published pages marked for the footer
    * `path` – the current path, to highlight the active entry
    * `category_slugs` – the category trail of a category or product page
      (`put_category_trail/2`), so its main category is highlighted

  Pages are shown with their published title.
  """
  @behaviour Plug

  alias Mercator.{Catalog, Content}

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts),
    do: Plug.Conn.assign(conn, :nav, Map.put(load(), :path, conn.request_path))

  # the chat panel is rendered inside every page and has no URL of its own
  def on_mount(:default, _params, _session, %{view: MercatorWeb.ChatLive} = socket),
    do: {:cont, Phoenix.Component.assign_new(socket, :nav, &load/0)}

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> Phoenix.Component.assign_new(:nav, &load/0)
     |> Phoenix.LiveView.attach_hook(:nav_path, :handle_params, fn _params, uri, socket ->
       {:cont, put_nav(socket, :path, URI.parse(uri).path)}
     end)}
  end

  @doc "Highlights the main category of these categories (a trail from the root)."
  def put_category_trail(socket, categories),
    do: put_nav(socket, :category_slugs, Enum.map(categories, & &1.slug))

  defp put_nav(socket, key, value),
    do: Phoenix.Component.update(socket, :nav, &Map.put(&1, key, value))

  @doc "The navigation map, see the module doc."
  def load do
    offline = Content.offline_paths()
    reachable = &Content.reachable?(&1, offline)

    %{
      # hidden categories are reachable by link but not listed (#52)
      categories:
        Enum.filter(Catalog.list_root_categories!(load: :images), &(&1.state == :active)),
      main: Enum.filter(Content.list_menu_pages!(:main), reachable),
      footer: Enum.filter(Content.list_menu_pages!(:footer), reachable)
    }
  end

  @doc "An empty navigation, e.g. for pages rendered without the plug."
  def empty, do: %{categories: [], main: [], footer: []}
end
