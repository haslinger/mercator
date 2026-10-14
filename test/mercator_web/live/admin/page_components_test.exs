defmodule MercatorWeb.Admin.PageComponentsTest do
  use ExUnit.Case, async: true

  alias MercatorWeb.Admin.PageComponents

  test "the picker offers all installed Heroicons (regenerate the list when they change)" do
    installed =
      "deps/heroicons/optimized/24/outline"
      |> File.ls!()
      |> Enum.map(&("hero-" <> Path.rootname(&1)))
      |> Enum.sort()

    assert Enum.sort(PageComponents.page_icons()) == installed
  end

  test "searching keeps the chosen icon" do
    assert PageComponents.matching_icons("truck", nil) == ["hero-truck"]

    assert PageComponents.matching_icons("truck", "hero-envelope") == [
             "hero-envelope",
             "hero-truck"
           ]

    assert length(PageComponents.matching_icons("", nil)) == length(PageComponents.page_icons())
  end
end
