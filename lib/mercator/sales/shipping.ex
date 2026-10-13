defmodule Mercator.Sales.Shipping do
  @moduledoc """
  Shipping methods and costs (#65), configured per deployment:

      config :mercator, :shipping,
        parcel: [rates: [%{countries: ~w(AT), gross: "9.90", free_from: "250"}]],
        freight: [estimate: true, rates: [%{countries: ~w(AT), gross: "89"}]],
        pickup: []

  The order of the keys is the display order; leaving a method out disables
  it. Amounts are gross EUR (what the customer sees). `free_from` compares
  with the gross value of the goods. Freight costs with `estimate: true` are
  "from" prices that staff confirm. Pickup is always free.
  """

  alias Mercator.Sales.ShippingMethod

  @doc "The enabled shipping methods in display order."
  def enabled, do: Keyword.keys(config())

  @doc """
  The shipping methods possible for a basket with the given products: one
  `:pickup_only` product forces pickup, one `:freight` product excludes the
  parcel. Services (`:none`) don't need shipping; a basket of services only
  is picked up (free).
  """
  def methods_for(products) do
    kinds = products |> Enum.map(& &1.shipping) |> Enum.reject(&(&1 == :none)) |> Enum.uniq()

    candidates =
      cond do
        kinds == [] -> [:pickup]
        :pickup_only in kinds -> [:pickup]
        :freight in kinds -> [:freight, :pickup]
        true -> [:parcel, :pickup]
      end

    Enum.filter(enabled(), &(&1 in candidates))
  end

  @doc """
  The shipping costs of a method for a delivery country and the gross value
  of the goods: `{:ok, %{gross: Decimal, estimate?: boolean}}` or
  `{:error, :not_available}` if the method doesn't deliver there.
  """
  def cost(:pickup, _country, _goods_gross), do: {:ok, %{gross: Decimal.new(0), estimate?: false}}

  def cost(method, country, goods_gross) do
    with {:ok, options} <- Keyword.fetch(config(), method),
         %{} = rate <- Enum.find(Keyword.get(options, :rates, []), &(country in &1.countries)) do
      gross = if free?(rate, goods_gross), do: Decimal.new(0), else: Decimal.new(rate.gross)
      {:ok, %{gross: gross, estimate?: Keyword.get(options, :estimate, false)}}
    else
      _ -> {:error, :not_available}
    end
  end

  @doc "The order value from which a method is free in a country, or nil."
  def free_from(method, country) do
    with {:ok, options} <- Keyword.fetch(config(), method),
         %{free_from: free_from} <-
           Enum.find(Keyword.get(options, :rates, []), &(country in &1.countries)) do
      Decimal.new(free_from)
    else
      _ -> nil
    end
  end

  defdelegate label(method), to: ShippingMethod

  defp free?(%{free_from: free_from}, goods_gross),
    do: Decimal.compare(goods_gross, Decimal.new(free_from)) != :lt

  defp free?(_rate, _goods_gross), do: false

  defp config, do: Application.get_env(:mercator, :shipping, pickup: [])
end
