defmodule Mercator.Docs.Loader do
  @moduledoc """
  Reads the documentation sources into `Mercator.Docs.Chapter`s
  (docs/documentation-design.md, section 2). Used by `Mercator.Docs` at
  compile time, and by the tests with their own files.

  Sources are `{part, locale, path}` tuples. Pages may start with a front
  matter block between `---` lines, with `key: value` and `key: [a, b]`
  lines (title, roles, order, pages); otherwise the title is the first
  heading, and the file name decides the order.

  Links between the sources (`[Katalog](catalog-design.md)`) become links
  to their chapters; other relative links (to code files, which the app
  cannot show) keep only their text.
  """

  alias Mercator.Docs.Chapter

  @markdown [
    extension: [strikethrough: true, table: true, autolink: true, header_id_prefix: ""],
    render: [escape: true]
  ]

  @doc """
  Loads the sources. `link_to` turns `{part, slug}` into the URL of a
  chapter, for the links between them.
  """
  def load(sources, link_to) do
    chapters = Enum.map(sources, fn {part, locale, path} -> read(part, locale, path) end)
    targets = Map.new(chapters, &{Path.basename(&1.source), {&1.part, &1.slug}})

    Enum.map(chapters, fn chapter ->
      %{chapter | html: rewrite_links(chapter.html, targets, link_to)}
    end)
  end

  defp read(part, locale, path) do
    {meta, body} = path |> File.read!() |> front_matter()
    {title, body} = title(meta, body, path)
    html = MDEx.to_html!(body, @markdown)

    %Chapter{
      part: part,
      slug: Path.basename(path, ".md"),
      locale: locale,
      title: title,
      html: html,
      source: path,
      order: meta |> Map.get("order", "100") |> String.to_integer(),
      roles: meta |> Map.get("roles", []) |> List.wrap() |> Enum.map(&role/1),
      pages: meta |> Map.get("pages", []) |> List.wrap(),
      toc: toc(html),
      text: MercatorWeb.Markdown.to_text(body)
    }
  end

  @doc ~S"""
  Splits off a front matter block.

      iex> Mercator.Docs.Loader.front_matter("---\ntitle: Hilfe\nroles: [sales, administrator]\n---\nText")
      {%{"title" => "Hilfe", "roles" => ["sales", "administrator"]}, "Text"}

      iex> Mercator.Docs.Loader.front_matter("# Nur Text")
      {%{}, "# Nur Text"}
  """
  def front_matter("---\n" <> rest) do
    [head, body] = String.split(rest, ~r/^---\n/m, parts: 2)

    meta =
      for line <- String.split(head, "\n", trim: true), into: %{} do
        [key, value] = String.split(line, ":", parts: 2)
        {String.trim(key), value(String.trim(value))}
      end

    {meta, String.trim_leading(body)}
  end

  def front_matter(text), do: {%{}, text}

  defp value("[" <> list),
    do:
      list
      |> String.trim_trailing("]")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)

  defp value(value), do: value

  # the title from the front matter, else the first heading (taken out of the body)
  defp title(%{"title" => title}, body, _path), do: {title, body}

  defp title(_meta, body, path) do
    case Regex.run(~r/\A#\s+(.+)\n/, body) do
      [heading, title] -> {String.trim(title), String.replace_prefix(body, heading, "")}
      nil -> {Path.basename(path, ".md"), body}
    end
  end

  # only known roles, as atoms
  defp role(role)
       when role in ~w(administrator sales sales_manager contentmanager productmanager),
       do: String.to_existing_atom(role)

  defp toc(html) do
    for [_tag, level, id, text] <- Regex.scan(~r/<h([23]) id="([^"]+)">(.*?)<a href/, html) do
      {String.to_integer(level), id, text}
    end
  end

  defp rewrite_links(html, targets, link_to) do
    Regex.replace(~r/<a href="([^"]*)">(.*?)<\/a>/s, html, fn whole, href, text ->
      cond do
        String.match?(href, ~r/^(https?:|mailto:|#|\/)/) ->
          whole

        target = Map.get(targets, href |> String.split("#") |> hd() |> Path.basename()) ->
          ~s(<a href="#{link_to.(target)}#{anchor(href)}">#{text}</a>)

        true ->
          text
      end
    end)
  end

  defp anchor(href) do
    case String.split(href, "#", parts: 2) do
      [_path, anchor] -> "#" <> anchor
      [_path] -> ""
    end
  end
end
