defmodule Mercator.BrokenPaymentProvider do
  @moduledoc "A payment provider for tests that is always down."
  @behaviour Mercator.Payments.Provider

  @impl true
  def key, do: :broken

  @impl true
  def name, do: "Broken"

  @impl true
  def available?, do: true

  @impl true
  def setup_hint, do: nil

  @impl true
  def create_payment(_order, _amount, _urls), do: {:error, :timeout}

  @impl true
  def fetch_payment(_id), do: {:error, :timeout}

  @impl true
  def refund(_id, _amount), do: {:error, :timeout}
end
