defmodule MercatorWeb.AuthComponents do
  @moduledoc """
  Extra fields for the AshAuthentication.Phoenix forms, plugged in through
  `MercatorWeb.AuthOverrides`.
  """
  use MercatorWeb, :html

  @doc """
  The mandatory name on the registration form (#102), styled like the
  library's own fields (see `Components.Password.Input` in the overrides).
  """
  attr :form, Phoenix.HTML.Form, required: true

  def name_field(assigns) do
    field = assigns.form[:name]
    errors = if used_input?(field), do: field.errors, else: []
    assigns = assign(assigns, field: field, errors: Enum.map(errors, &translate_error/1))

    ~H"""
    <div class="fieldset">
      <label for={@field.id} class="fieldset-legend">{gettext("Name")}</label>
      <input
        type="text"
        id={@field.id}
        name={@field.name}
        value={@field.value}
        autocomplete="name"
        required
        class={["input w-full", @errors != [] && "input-error"]}
      />
      <ul :if={@errors != []} class="text-error text-sm mt-1">
        <li :for={error <- @errors}>{error}</li>
      </ul>
      <p class="text-sm text-base-content/60 mt-1">
        {gettext("How we may address you; also used on offers and orders.")}
      </p>
    </div>
    """
  end
end
