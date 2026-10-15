defmodule Mercator.Sales.PaymentMethod do
  @moduledoc """
  How an order is paid (#64); `:online` with the active payment provider
  (phase 7, #110).
  """
  use Ash.Type.Enum, values: [:online, :prepayment, :invoice, :on_pickup]

  use Gettext, backend: MercatorWeb.Gettext

  @doc "The translated name of a payment method."
  def label(:online), do: pgettext("payment method", "Pay online")
  def label(:prepayment), do: pgettext("payment method", "Prepayment")
  def label(:invoice), do: pgettext("payment method", "Invoice")
  def label(:on_pickup), do: pgettext("payment method", "Payment on pickup")
end
