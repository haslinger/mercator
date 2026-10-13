defmodule MercatorWeb.TranslatedComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import MercatorWeb.TranslatedComponents

  defp field(value) do
    form = Phoenix.Component.to_form(%{"name" => value}, as: :category)
    form[:name]
  end

  defp inputs(html) do
    html |> LazyHTML.from_fragment() |> LazyHTML.query("input") |> Enum.map(&attributes/1)
  end

  defp attributes(node) do
    for attr <- ["name", "value", "id"], into: %{} do
      {attr, node |> LazyHTML.attribute(attr) |> List.first()}
    end
  end

  test "renders one input per content locale with the stored values" do
    html =
      render_component(&translated_input/1,
        field: field(%{"de" => "Lärche", "en" => "Larch"}),
        label: "Name"
      )

    assert inputs(html) == [
             %{"name" => "category[name][de]", "value" => "Lärche", "id" => "category_name_de"},
             %{"name" => "category[name][en]", "value" => "Larch", "id" => "category_name_en"}
           ]

    assert html =~ "Name (DE)"
    assert html =~ "Name (EN)"
  end

  test "renders empty inputs for a nil value" do
    html = render_component(&translated_input/1, field: field(nil), label: "Name")

    assert Enum.map(inputs(html), & &1["value"]) == [nil, nil]
  end

  test "renders textareas" do
    html =
      render_component(&translated_input/1,
        field: field(%{"de" => "Text"}),
        label: "Beschreibung",
        type: "textarea"
      )

    assert html =~ "<textarea"
    assert html =~ "Text"
  end
end
