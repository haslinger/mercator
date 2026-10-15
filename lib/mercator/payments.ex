defmodule Mercator.Payments do
  @moduledoc """
  Online payment (phase 7, docs/payment-design.md): the payment providers
  of this deployment and the active one.

  Providers are registered per deployment in config, with their credentials
  from the environment:

      config :mercator, :payment_providers, [Mercator.Payments.Mollie]

  Administrators only switch between them (or switch online payment off);
  the choice is the runtime setting `"payment_provider"`. A payment keeps
  the provider it was started with, so switching does not affect open
  payments.
  """
  alias Mercator.Operations.Settings

  @setting "payment_provider"

  @doc "The registered provider modules, in config order."
  def providers, do: Application.get_env(:mercator, :payment_providers, [])

  @doc "The provider module with this key (also for payments made earlier), or nil."
  def provider(key) do
    key = to_string(key)
    Enum.find(providers(), &(to_string(&1.key()) == key))
  end

  @doc """
  The active provider module: the one chosen in the back office, if it is
  registered and available. nil means no online payment.
  """
  def active do
    case Settings.get(@setting) do
      %{"key" => key} when is_binary(key) ->
        with provider when not is_nil(provider) <- provider(key),
             true <- provider.available?() do
          provider
        else
          _ -> nil
        end

      _none ->
        nil
    end
  end

  @doc "Whether customers can pay online right now."
  def online?, do: active() != nil

  @doc """
  Switches the active provider (by key), or off with nil. Administrators
  only; the provider must be registered and available.
  """
  def activate(nil, actor), do: Settings.put(@setting, %{"key" => nil}, actor)

  def activate(key, actor) do
    case provider(key) do
      nil ->
        {:error, :unknown_provider}

      provider ->
        if provider.available?(),
          do: Settings.put(@setting, %{"key" => to_string(provider.key())}, actor),
          else: {:error, :not_available}
    end
  end
end
