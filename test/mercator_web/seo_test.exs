defmodule MercatorWeb.SeoTest do
  use MercatorWeb.ConnCase, async: true

  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Content
  alias MercatorWeb.Seo

  defp document(conn, path) do
    conn |> get(path) |> html_response(200) |> LazyHTML.from_document()
  end

  defp attr(document, selector, name) do
    document |> LazyHTML.query(selector) |> LazyHTML.attribute(name) |> List.first()
  end

  describe "meta tags" do
    test "product pages describe the product and name their canonical URL", %{conn: conn} do
      product =
        product_fixture(
          title: %{"de" => "Lärchenbrett"},
          description: %{"de" => "**Sägerau**, aus dem Waldviertel."}
        )

      document = document(conn, ~p"/products/#{product.slug}")

      assert attr(document, ~s(meta[name="description"]), "content") ==
               "Sägerau, aus dem Waldviertel."

      assert attr(document, ~s(link[rel="canonical"]), "href") =~ "/products/#{product.slug}"
      assert attr(document, ~s(meta[property="og:title"]), "content") == "Lärchenbrett"
    end

    test "CMS pages use their SEO text, or the start of their first text", %{conn: conn} do
      editor = user_fixture(roles: [:contentmanager])

      %{
        title: %{"de" => "Sägewerk"},
        slug: "seo-saegewerk",
        blocks: [%{type: "text", text: %{"de" => "## Seit 1928\nWir sägen heimisches Holz."}}]
      }
      |> Content.create_page!(actor: editor)
      |> Content.publish_page!(actor: editor)

      document = document(conn, ~p"/pages/seo-saegewerk")

      assert attr(document, ~s(meta[name="description"]), "content") ==
               "Seit 1928 Wir sägen heimisches Holz."

      assert attr(document, ~s(link[rel="canonical"]), "href") =~ "/pages/seo-saegewerk"
    end

    test "long descriptions are cut at a word" do
      text = String.duplicate("Holz ", 50)
      description = Seo.description(text)

      assert String.length(description) <= 162
      assert String.ends_with?(description, " …")
    end
  end

  test "the sitemap lists start page, published pages, categories and products", %{conn: conn} do
    editor = user_fixture(roles: [:contentmanager])
    category = category_fixture(slug: "seo-bauholz", state: :active)
    product = product_fixture(title: %{"de" => "Sitemap-Balken"})

    %{title: %{"de" => "Impressum"}, slug: "seo-impressum"}
    |> Content.create_page!(actor: editor)
    |> Content.publish_page!(actor: editor)

    Content.create_page!(%{title: %{"de" => "Entwurf"}, slug: "seo-entwurf"}, actor: editor)

    xml = conn |> get(~p"/sitemap.xml") |> response(200)

    assert xml =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
    assert xml =~ "/pages/seo-impressum</loc><lastmod>"
    assert xml =~ "/categories/#{category.slug}</loc>"
    assert xml =~ "/products/#{product.slug}</loc>"
    refute xml =~ "seo-entwurf"
  end

  test "robots.txt points to the sitemap", %{conn: conn} do
    text = conn |> get(~p"/robots.txt") |> response(200)

    assert text =~ "Sitemap: http"
    assert text =~ "/sitemap.xml"
    assert text =~ "Disallow: /admin"
  end
end
