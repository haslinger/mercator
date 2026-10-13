# Regenerates assets/lists/images.csv from the demo data in the dev database:
#
#     mix run priv/repo/image_list.exs
alias Mercator.Catalog
alias Mercator.Translated

out = Path.join(File.cwd!(), "assets/lists/images.csv")

csv = fn fields ->
  Enum.map_join(fields, ",", fn field ->
    field = to_string(field || "")

    if String.contains?(field, [",", "\"", "\n"]),
      do: "\"" <> String.replace(field, "\"", "\"\"") <> "\"",
      else: field
  end)
end

t = fn value, locale -> Translated.t(value, locale) end

categories =
  Catalog.list_categories!(authorize?: false, load: [:parent])
  |> Enum.sort_by(&{length(&1.path), &1.parent && &1.parent.position, &1.position})

products =
  Catalog.list_products!(authorize?: false, load: [:categories, product_properties: :property])
  |> Enum.sort_by(& &1.number)

species = fn product ->
  Enum.find_value(product.product_properties, fn pp ->
    if pp.property.name["de"] == "Holzart", do: t.(pp.text_value, "en")
  end)
end

category_rows =
  for c <- categories do
    kind = if c.parent, do: "subcategory", else: "category"
    parent = if c.parent, do: t.(c.parent.name, "de"), else: ""

    prompt =
      "#{t.(c.name, "en")}" <>
        if(c.description, do: " – #{t.(c.description, "en")}", else: "") <>
        if(c.parent, do: " (part of: #{t.(c.parent.name, "en")})", else: "")

    [
      "categories/#{c.slug}.webp",
      kind,
      c.slug,
      parent,
      t.(c.name, "de"),
      t.(c.name, "en"),
      prompt
    ]
  end

product_rows =
  for p <- products do
    category = p.categories |> List.first() |> then(&(&1 && t.(&1.name, "de")))
    wood = species.(p)

    prompt =
      [
        t.(p.title, "en"),
        p.subtitle && t.(p.subtitle, "en"),
        p.description && t.(p.description, "en"),
        wood && "wood species: #{wood}"
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" – ")

    [
      "products/#{p.number}.webp",
      "product",
      p.number,
      category,
      t.(p.title, "de"),
      t.(p.title, "en"),
      prompt
    ]
  end

header = ["file", "type", "number_or_slug", "category", "name_de", "name_en", "image_prompt_en"]
File.write!(out, Enum.map_join([header | category_rows ++ product_rows], "\n", csv) <> "\n")
IO.puts("#{length(category_rows)} categories, #{length(product_rows)} products -> #{out}")
