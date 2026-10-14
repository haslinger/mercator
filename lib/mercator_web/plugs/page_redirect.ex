defmodule MercatorWeb.Plugs.PageRedirect do
  @moduledoc """
  Permanent redirects (301) for former page paths (`Mercator.Content.PageRedirect`):
  a request for `/pages/<path>` where no page has that path, but a page had
  it before, goes to the page's current URL. Query strings are kept.
  """
  @behaviour Plug

  import Plug.Conn

  require Ash.Query

  alias Mercator.Content
  alias Mercator.Content.Page

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "GET", path_info: ["pages" | segments]} = conn, _opts) when segments != [] do
    path = Enum.join(segments, "/")

    with false <- Page |> Ash.Query.filter(path == ^path) |> Ash.exists?(authorize?: false),
         %{page_id: page_id} <- Content.get_page_redirect!(path, authorize?: false),
         {:ok, page} <- Ash.get(Page, page_id, authorize?: false) do
      target = MercatorWeb.Layouts.page_path(page) <> query(conn)

      conn
      |> put_resp_header("location", target)
      |> send_resp(301, "")
      |> halt()
    else
      _ -> conn
    end
  end

  def call(conn, _opts), do: conn

  defp query(%{query_string: ""}), do: ""
  defp query(%{query_string: query}), do: "?" <> query
end
