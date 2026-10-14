defmodule MercatorWeb.SitemapController do
  @moduledoc """
  `/sitemap.xml` and `/robots.txt` for search engines (#91). The sitemap
  lists the start page, the published CMS pages, the active categories and
  the active products; robots.txt points to it with this deployment's host.
  """
  use MercatorWeb, :controller

  require Ash.Query

  alias Mercator.Catalog.{Category, Product}
  alias Mercator.Content.Page
  alias MercatorWeb.{Layouts, Seo}

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml(entries()))
  end

  def robots(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(
      200,
      "User-agent: *\nDisallow: /admin\nDisallow: /account\nDisallow: /checkout\n\nSitemap: #{Seo.absolute(~p"/sitemap.xml")}\n"
    )
  end

  defp entries do
    offline = Mercator.Content.offline_paths()

    pages =
      Page
      |> Ash.Query.filter(
        kind == :page and state == :published and (is_nil(key) or key != "home")
      )
      |> Ash.Query.sort(path: :asc)
      |> Ash.read!()
      |> Enum.filter(&Mercator.Content.reachable?(&1, offline))
      |> Enum.map(&{Layouts.page_path(&1), &1.published_at})

    categories =
      Category
      |> Ash.Query.filter(state == :active)
      |> Ash.Query.sort(path: :asc)
      |> Ash.read!()
      |> Enum.map(&{~p"/categories/#{&1.slug}", &1.updated_at})

    products =
      Product
      |> Ash.Query.filter(state == :active)
      |> Ash.Query.sort(number: :asc)
      |> Ash.read!()
      |> Enum.map(&{~p"/products/#{&1.slug}", &1.updated_at})

    [{~p"/", nil} | pages ++ categories ++ products]
  end

  defp xml(entries) do
    urls =
      Enum.map_join(entries, "\n", fn {path, modified} ->
        lastmod =
          if modified,
            do: "<lastmod>#{Date.to_iso8601(DateTime.to_date(modified))}</lastmod>",
            else: ""

        "  <url><loc>#{escape(Seo.absolute(path))}</loc>#{lastmod}</url>"
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{urls}
    </urlset>
    """
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
