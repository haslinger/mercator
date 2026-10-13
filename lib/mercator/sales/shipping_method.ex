defmodule Mercator.Sales.ShippingMethod do
  @moduledoc """
  How an order reaches the customer (#65): `:parcel`, `:freight` (forwarding
  agent, e.g. pallets and long timber) or `:pickup` at the shop's address.
  """
  use Ash.Type.Enum, values: [:parcel, :freight, :pickup]

  use Gettext, backend: MercatorWeb.Gettext

  @doc "The translated name of a shipping method."
  def label(:parcel), do: pgettext("shipping method", "Parcel")
  def label(:freight), do: pgettext("shipping method", "Freight forwarding")
  def label(:pickup), do: pgettext("shipping method", "Pickup")
end
