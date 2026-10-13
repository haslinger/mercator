defmodule Mercator.TranslatedTest do
  use ExUnit.Case, async: true

  alias Mercator.Translated

  defp cast(value, constraints \\ []) do
    with {:ok, value} <- Ash.Type.cast_input(Translated, value, constraints) do
      Ash.Type.apply_constraints(Translated, value, constraints)
    end
  end

  describe "casting" do
    test "accepts string and atom locale keys" do
      assert cast(%{"de" => "Lärche", en: "Larch"}) == {:ok, %{"de" => "Lärche", "en" => "Larch"}}
    end

    test "trims text and drops empty translations" do
      assert cast(%{"de" => "  Fichte ", "en" => "   "}) == {:ok, %{"de" => "Fichte"}}
    end

    test "a map without any translation becomes nil" do
      assert cast(%{"de" => "", "en" => nil}) == {:ok, nil}
      assert cast(%{}) == {:ok, nil}
    end

    test "rejects unknown locales, plain strings and non-string translations" do
      assert {:error, _} = cast(%{"fr" => "Mélèze"})
      assert {:error, _} = cast("Lärche")
      assert {:error, _} = cast(%{"de" => 42})
    end
  end

  describe "constraints" do
    test "required locales must be present" do
      assert {:ok, _} = cast(%{"de" => "Eiche"}, required: ["de"])
      assert {:error, [error]} = cast(%{"en" => "Oak"}, required: ["de"])
      assert error[:locale] == "de"
    end

    test "max_length applies to every translation" do
      assert {:ok, _} = cast(%{"de" => "Zirbe"}, max_length: 5)

      assert {:error, [error]} =
               cast(%{"de" => "Zirbe", "en" => "Swiss stone pine"}, max_length: 5)

      assert error[:locale] == "en"
    end
  end

  describe "t/2" do
    @value %{"de" => "Lärche", "en" => "Larch"}

    test "returns the translation for the locale" do
      assert Translated.t(@value, "en") == "Larch"
      assert Translated.t(@value, :de) == "Lärche"
    end

    test "falls back to the default locale, then to any translation" do
      assert Translated.t(@value, "fr") == "Lärche"
      assert Translated.t(%{"en" => "Larch"}, "de") == "Larch"
    end

    test "handles nil" do
      assert Translated.t(nil, "de") == nil
    end
  end

  test "the content locales match the UI locales" do
    assert Enum.sort(Translated.locales()) == Enum.sort(MercatorWeb.Locale.locales())
    assert Translated.default_locale() == "de"
  end
end
