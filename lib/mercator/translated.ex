defmodule Mercator.Translated do
  @moduledoc """
  Ash type for translatable content (decision #7): a map from locale to text,
  stored as JSONB, e.g. `%{"de" => "Lärche", "en" => "Larch"}`.

  * Keys are the content locales (`locales/0`); unknown keys are rejected.
  * Text is trimmed; empty translations are dropped. A map without any
    translation casts to `nil`, so `allow_nil? false` means "at least one".
  * Constraints:
    * `required` – locales that must be present, e.g. `["de"]`
    * `max_length` – maximum length of each translation

  Use `t/2` to read a translation with fallback to the default locale.

      attribute :name, Mercator.Translated do
        allow_nil? false
        constraints required: ["de"], max_length: 200
      end
  """
  use Ash.Type
  use Gettext, backend: MercatorWeb.Gettext

  @constraints [
    required: [
      type: {:list, :string},
      default: [],
      doc: "Locales that must have a translation."
    ],
    max_length: [
      type: :pos_integer,
      doc: "Maximum length of each translation."
    ]
  ]

  @doc "The content locales, as strings. The first one is the default."
  def locales, do: Application.get_env(:mercator, :content_locales, ["de", "en"])

  @doc "The default content locale, used as fallback."
  def default_locale, do: hd(locales())

  @doc """
  The translation for `locale`, falling back to the default locale and then
  to any translation. Returns nil for nil or empty values.
  """
  def t(nil, _locale), do: nil

  def t(translated, locale) when is_map(translated) do
    translated[to_string(locale)] || translated[default_locale()] ||
      translated |> Map.values() |> List.first()
  end

  @impl Ash.Type
  def constraints, do: @constraints

  @impl Ash.Type
  def storage_type(_constraints), do: :map

  @impl Ash.Type
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, _constraints) when is_binary(value) do
    {:error, "must be a map of translations, e.g. %{\"de\" => \"...\"}"}
  end

  def cast_input(value, _constraints) when is_map(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {locale, text}, {:ok, acc} ->
      locale = to_string(locale)

      cond do
        locale not in locales() ->
          {:halt, {:error, "unknown locale #{inspect(locale)}"}}

        is_nil(text) ->
          {:cont, {:ok, acc}}

        is_binary(text) ->
          {:cont, {:ok, put_text(acc, locale, String.trim(text))}}

        true ->
          {:halt, {:error, "translation for #{locale} must be a string"}}
      end
    end)
    |> case do
      {:ok, map} when map_size(map) == 0 -> {:ok, nil}
      other -> other
    end
  end

  def cast_input(_value, _constraints), do: :error

  defp put_text(map, _locale, ""), do: map
  defp put_text(map, locale, text), do: Map.put(map, locale, text)

  @impl Ash.Type
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(value, _constraints) when is_map(value), do: {:ok, value}
  def cast_stored(_value, _constraints), do: :error

  @impl Ash.Type
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(value, _constraints) when is_map(value), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error

  @impl Ash.Type
  def apply_constraints(nil, _constraints), do: {:ok, nil}

  def apply_constraints(value, constraints) do
    errors =
      missing_errors(value, constraints[:required] || []) ++
        length_errors(value, constraints[:max_length])

    case errors do
      [] -> {:ok, value}
      errors -> {:error, errors}
    end
  end

  defp missing_errors(value, required) do
    for locale <- required, !Map.has_key?(value, locale) do
      [message: dgettext_noop("errors", "translation for %{locale} is missing"), locale: locale]
    end
  end

  defp length_errors(_value, nil), do: []

  defp length_errors(value, max) do
    for {locale, text} <- value, String.length(text) > max do
      [
        message:
          dgettext_noop("errors", "translation for %{locale} must be at most %{max} characters"),
        locale: locale,
        max: max
      ]
    end
  end
end
