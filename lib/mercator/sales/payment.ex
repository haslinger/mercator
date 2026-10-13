defmodule Mercator.Sales.Payment do
  @moduledoc """
  Payment methods offered at checkout (#64), configured per deployment with
  `config :mercator, :payment_methods, [:prepayment, :invoice, :on_pickup]`.

  - `:prepayment`: always; the bank account comes from the brand config.
  - `:invoice`: only for customers approved by staff (`invoice_allowed`).
  - `:on_pickup`: only with the shipping method `:pickup`.
  """

  alias Mercator.Sales.PaymentMethod

  @doc "The enabled payment methods in display order."
  def enabled, do: Application.get_env(:mercator, :payment_methods, [:prepayment])

  @doc "The payment methods a customer can choose for a shipping method."
  def methods_for(user, shipping_method) do
    Enum.filter(enabled(), &allowed?(&1, user, shipping_method))
  end

  @doc "The bank account for prepayment (`Mercator.Brand` key `:bank`), or nil."
  def bank_account, do: Mercator.Brand.get(:bank)

  defdelegate label(method), to: PaymentMethod

  defp allowed?(:prepayment, _user, _shipping_method), do: true
  defp allowed?(:invoice, user, _shipping_method), do: user.invoice_allowed == true
  defp allowed?(:on_pickup, _user, shipping_method), do: shipping_method == :pickup
end
