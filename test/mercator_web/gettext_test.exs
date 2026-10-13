defmodule MercatorWeb.GettextTest do
  use ExUnit.Case, async: true

  # Gettext ignores "fuzzy" translations at runtime, so the German text would
  # silently fall back to English.
  test "translation files contain no fuzzy entries" do
    for file <- Path.wildcard("priv/gettext/*/LC_MESSAGES/*.po") do
      refute File.read!(file) =~ "fuzzy", "#{file} contains fuzzy translations"
    end
  end

  test "all German UI texts are translated" do
    for file <- Path.wildcard("priv/gettext/de/LC_MESSAGES/*.po") do
      untranslated =
        file
        |> File.read!()
        |> String.split("\n\n")
        |> Enum.filter(&(&1 =~ ~r/^msgid "[^"]/m and &1 =~ ~r/^msgstr(\[0\])? ""$/m))

      assert untranslated == [],
             "#{file} has untranslated entries:\n#{Enum.join(untranslated, "\n\n")}"
    end
  end

  test "badges and VAT notes are German" do
    Gettext.with_locale(MercatorWeb.Gettext, "de", fn ->
      assert Gettext.gettext(MercatorWeb.Gettext, "Sale") == "Aktion"
      assert Gettext.gettext(MercatorWeb.Gettext, "Administration") == "Verwaltung"
    end)
  end
end
