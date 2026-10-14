defmodule MercatorWeb.Admin.PageComponents do
  @moduledoc "Small components shared by the CMS pages in the back office."
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext

  attr :state, :atom, required: true
  attr :id, :string, default: nil

  def page_state_badge(assigns) do
    ~H"""
    <span
      class={[
        "badge badge-sm",
        @state == :published && "badge-success",
        @state == :hidden && "badge-warning",
        @state == :draft && "badge-ghost",
        @state == :archived && "badge-neutral"
      ]}
      id={@id}
    >
      {page_state_label(@state)}
    </span>
    """
  end

  @doc "The translated name of a page state."
  def page_state_label(:draft), do: pgettext("page state", "Draft")
  def page_state_label(:published), do: pgettext("page state", "Published")
  def page_state_label(:hidden), do: pgettext("page state", "Hidden")
  def page_state_label(:archived), do: pgettext("page state", "Archived")

  @doc "The translated name of a menu placement."
  def menu_label(:none), do: gettext("Not in a menu")
  def menu_label(:main), do: gettext("Main navigation")
  def menu_label(:footer), do: gettext("Footer")

  @doc "Options for the menu select."
  def menu_options, do: Enum.map([:none, :main, :footer], &{menu_label(&1), &1})

  @icons ~w(
    hero-home hero-information-circle hero-building-storefront hero-building-office
    hero-wrench-screwdriver hero-cog-6-tooth hero-question-mark-circle hero-envelope
    hero-phone hero-map-pin hero-clock hero-truck hero-sparkles hero-star hero-heart
    hero-light-bulb hero-fire hero-sun hero-gift hero-camera hero-newspaper
    hero-document-text hero-scale hero-shield-check hero-users hero-user-group
  )

  @doc "The icons pages can have in the navigation (Heroicons)."
  def page_icons, do: @icons

  attr :field, Phoenix.HTML.FormField, required: true

  @doc "Choose a page's icon: a grid of icons as radio buttons, or none."
  def icon_picker(assigns) do
    ~H"""
    <fieldset class="fieldset" id="icon-picker">
      <legend class="fieldset-legend">{gettext("Icon in the navigation")}</legend>
      <div class="grid grid-cols-7 gap-1">
        <label
          class={[
            "btn btn-square btn-sm",
            if(@field.value in [nil, ""], do: "btn-primary", else: "btn-ghost")
          ]}
          title={gettext("No icon")}
        >
          <input
            type="radio"
            name={@field.name}
            value=""
            checked={@field.value in [nil, ""]}
            class="sr-only"
          />
          <MercatorWeb.CoreComponents.icon name="hero-minus" class="size-4" />
        </label>
        <label
          :for={icon <- page_icons()}
          class={[
            "btn btn-square btn-sm",
            if(@field.value == icon, do: "btn-primary", else: "btn-ghost")
          ]}
          title={String.replace_prefix(icon, "hero-", "")}
          id={"icon-#{icon}"}
        >
          <input
            type="radio"
            name={@field.name}
            value={icon}
            checked={@field.value == icon}
            class="sr-only"
          />
          <MercatorWeb.CoreComponents.icon name={icon} class="size-5" />
        </label>
      </div>
    </fieldset>
    """
  end
end
