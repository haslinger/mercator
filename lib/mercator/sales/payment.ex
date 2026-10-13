defmodule Mercator.Sales.Payment do
  @moduledoc """
  Payment methods offered at checkout (#64), configured per deployment with
  `config :mercator, :payment_methods, [:prepayment, :invoice, :on_pickup]`.

  - `:prepayment`: always; the bank account comes from the brand config.
  - `:invoice`: only for customers approved by staff (`invoice_allowed`).
  - `:on_pickup`: only with the shipping method `:pickup`.
  """

  use Gettext, backend: MercatorWeb.Gettext

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

  @doc """
  Payment instructions for an order, as lines of text in the current
  locale (confirmation page and email).
  """
  def instructions(%{payment_method: :prepayment} = order) do
    amount = MercatorWeb.Format.money(order.gross, Gettext.get_locale(MercatorWeb.Gettext))

    intro =
      if order.shipping_estimate do
        gettext(
          "We will confirm the freight costs first. Then please transfer the final amount, stating the order number %{number}, to:",
          number: order.number
        )
      else
        gettext("Please transfer %{amount}, stating the order number %{number}, to:",
          amount: amount,
          number: order.number
        )
      end

    case bank_account() do
      nil ->
        [intro]

      bank ->
        [intro, bank.holder, "IBAN #{bank.iban}", "BIC #{bank.bic}", bank.name]
        |> Enum.reject(&is_nil/1)
    end
  end

  def instructions(%{payment_method: :invoice}),
    do: [gettext("You will receive an invoice with the delivery, payable within 14 days.")]

  def instructions(%{payment_method: :on_pickup}),
    do: [gettext("Please pay when you pick up the goods, in cash or by card.")]

  defp allowed?(:prepayment, _user, _shipping_method), do: true
  defp allowed?(:invoice, user, _shipping_method), do: user.invoice_allowed == true
  defp allowed?(:on_pickup, _user, shipping_method), do: shipping_method == :pickup
end
