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
end
