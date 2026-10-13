defmodule MercatorWeb.TranslatedComponents do
  @moduledoc """
  Components for translatable content (`Mercator.Translated`).
  """
  use Phoenix.Component

  import MercatorWeb.CoreComponents, only: [input: 1, translate_error: 1]

  alias Mercator.Translated

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text", values: ~w(text textarea)
  attr :rest, :global, include: ~w(required rows maxlength placeholder)

  @doc """
  One input per content locale for a `Mercator.Translated` form field, sent as
  `field[de]`, `field[en]`, … Errors of the field are shown below the inputs.

      <.translated_input field={@form[:name]} label={gettext("Name")} />
  """
  def translated_input(assigns) do
    %{field: field} = assigns

    assigns =
      assigns
      |> assign(:value, field.value || %{})
      |> assign(
        :errors,
        if(used_input?(field), do: Enum.map(field.errors, &translate_error/1), else: [])
      )

    ~H"""
    <div id={@field.id} class="translated-input">
      <.input
        :for={locale <- Translated.locales()}
        type={@type}
        id={"#{@field.id}_#{locale}"}
        name={"#{@field.name}[#{locale}]"}
        value={value_for(@value, locale)}
        label={"#{@label} (#{String.upcase(locale)})"}
        {@rest}
      />
      <p :for={msg <- @errors} class="mt-1 text-sm text-error">{msg}</p>
    </div>
    """
  end

  # The value is a stored map (string keys) or submitted params.
  defp value_for(value, locale) when is_map(value) do
    value[locale] || value[String.to_existing_atom(locale)]
  end

  defp value_for(_value, _locale), do: nil
end
