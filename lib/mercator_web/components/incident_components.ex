defmodule MercatorWeb.IncidentComponents do
  @moduledoc "Labels and badges of incidents (#105) for the back office pages."
  use MercatorWeb, :html

  attr :state, :atom, required: true
  attr :id, :string, default: nil

  def state_badge(assigns) do
    ~H"""
    <span
      class={["badge", if(@state == :open, do: "badge-error", else: "badge-success badge-outline")]}
      id={@id}
    >
      {state_label(@state)}
    </span>
    """
  end

  attr :kind, :atom, required: true

  def kind_badge(assigns) do
    ~H"""
    <span class="badge badge-ghost badge-sm">{kind_label(@kind)}</span>
    """
  end

  @doc "The translated name of an incident state."
  def state_label(:open), do: pgettext("incident state", "Open")
  def state_label(:resolved), do: pgettext("incident state", "Resolved")

  @doc "The translated name of an incident kind."
  def kind_label(:manual), do: pgettext("incident kind", "Recorded by staff")
  def kind_label(:pdf), do: pgettext("incident kind", "PDF")
  def kind_label(:email), do: pgettext("incident kind", "Email")
  def kind_label(:job), do: pgettext("incident kind", "Background job")
  def kind_label(:payment), do: pgettext("incident kind", "Payment")
  def kind_label(:other), do: pgettext("incident kind", "Other")
end
