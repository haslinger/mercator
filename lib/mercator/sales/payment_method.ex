defmodule Mercator.Sales.PaymentMethod do
  @moduledoc """
  How an order is paid (#64). Online payment comes later (#14).
  """
  use Ash.Type.Enum, values: [:prepayment, :invoice, :on_pickup]

  use Gettext, backend: MercatorWeb.Gettext

  @doc "The translated name of a payment method."
  def label(:prepayment), do: pgettext("payment method", "Prepayment")
  def label(:invoice), do: pgettext("payment method", "Invoice")
  def label(:on_pickup), do: pgettext("payment method", "Payment on pickup")
end
