defmodule Mercator.SalesFixtures do
  @moduledoc """
  Test helpers for customers and orders.
  """

  import Mercator.AccountsFixtures

  alias Mercator.{Accounts, Sales}
  alias Mercator.Sales.{Baskets, Checkout}

  @doc "A user with an Austrian address, ready for checkout."
  def customer_fixture(address \\ %{}) do
    user = user_fixture()

    %{name: "Karl Luchs", street: "Waldweg 3", postcode: "6020", city: "Innsbruck", country: "AT"}
    |> Map.merge(Map.new(address))
    |> Accounts.create_address!(actor: user)

    user
  end

  @doc "The current GTC, needed to place orders."
  def gtc_fixture do
    # a date of its own per call: the version is unique, and async tests
    # inserting the same one wait for each other (and can deadlock)
    version = Date.add(~D[2026-10-01], -System.unique_integer([:positive]))
    Ash.Seed.seed!(Sales.Gtc, %{version: version, text: %{"de" => "AGB"}})
  end

  @doc """
  Places an order for `user` with `[{variant, quantity}]` (or one variant)
  through the checkout; `params` are checkout params such as
  `"shipping_method"`. Expects a GTC (`gtc_fixture/0`).
  """
  def order_fixture(user, lines, params \\ %{})

  def order_fixture(user, lines, params) when is_list(lines) do
    for {variant, quantity} <- lines, do: Baskets.add({:user, user}, variant.id, quantity)
    {:ok, order} = Checkout.place(user, Map.merge(%{"gtc" => "true"}, params))
    order
  end

  def order_fixture(user, variant, params), do: order_fixture(user, [{variant, 1}], params)
end
