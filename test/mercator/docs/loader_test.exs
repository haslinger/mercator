defmodule Mercator.Docs.LoaderTest do
  use ExUnit.Case, async: true

  alias Mercator.Docs.Loader

  doctest Loader

  @moduletag :tmp_dir

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)
    path
  end

  defp load(sources), do: Loader.load(sources, fn {part, slug} -> "/docs/#{part}/#{slug}" end)

  test "front matter: title, roles, order and pages", %{tmp_dir: dir} do
    path =
      write(dir, "orders.md", """
      ---
      title: Bestellungen bearbeiten
      roles: [sales, sales_manager]
      order: 30
      pages: [admin/orders, admin/orders/:number]
      ---
      ## Status ändern

      Text mit **Fettdruck**.
      """)

    [chapter] = load([{:manual, "de", path}])

    assert chapter.slug == "orders"
    assert chapter.title == "Bestellungen bearbeiten"
    assert chapter.roles == [:sales, :sales_manager]
    assert chapter.order == 30
    assert chapter.pages == ["admin/orders", "admin/orders/:number"]
    assert [{2, id, "Status ändern"}] = chapter.toc
    assert chapter.html =~ ~s(<h2 id="#{id}">)
    assert chapter.text == "Status ändern Text mit Fettdruck."
  end

  test "without front matter the first heading is the title", %{tmp_dir: dir} do
    path = write(dir, "notes.md", "# Notizen\n\nErster Absatz.\n")
    [chapter] = load([{:developers, "en", path}])

    assert chapter.title == "Notizen"
    refute chapter.html =~ "<h1"
    assert chapter.order == 100
  end

  test "links between sources point to their chapters, others keep their text", %{tmp_dir: dir} do
    target = write(dir, "payment-design.md", "# Payment\n\n## Steps\n")

    source =
      write(dir, "roadmap.md", """
      # Roadmap

      See [payment](payment-design.md), its [steps](payment-design.md#steps),
      the [code](lib/mercator/payments.ex) and [Mollie](https://www.mollie.com).
      """)

    chapters = load([{:developers, "en", target}, {:developers, "en", source}])
    roadmap = Enum.find(chapters, &(&1.slug == "roadmap"))

    assert roadmap.html =~ ~s(<a href="/docs/developers/payment-design">payment</a>)
    assert roadmap.html =~ ~s(<a href="/docs/developers/payment-design#steps">steps</a>)
    assert roadmap.html =~ ~s(<a href="https://www.mollie.com">Mollie</a>)
    refute roadmap.html =~ "payments.ex"
    assert roadmap.html =~ "the code and"
  end

  test "raw HTML is shown as text", %{tmp_dir: dir} do
    path = write(dir, "raw.md", "# Raw\n\n<script>alert(1)</script>\n")
    [chapter] = load([{:help, "de", path}])

    refute chapter.html =~ "<script>"
    assert chapter.html =~ "&lt;script&gt;"
  end

  test "an unknown role fails loudly", %{tmp_dir: dir} do
    path = write(dir, "bad.md", "---\ntitle: X\nroles: [chef]\n---\nText\n")
    assert_raise FunctionClauseError, fn -> load([{:manual, "de", path}]) end
  end
end
