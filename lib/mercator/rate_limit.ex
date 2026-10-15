defmodule Mercator.RateLimit do
  @moduledoc """
  Rate limiting in the app (#87, #126) with Hammer, counting in ETS (one
  node; Hammer has a Redis backend for several). Limits per bucket come
  from the config `:rate_limits`, as `{count, period_ms}`:

    * `:sign_in` – sign-in attempts per email address and client IP
    * `:sign_in_ip` – sign-in attempts per client IP, for all addresses
    * `:auth_email` – password reset and magic link emails per address and
      client IP
    * `:auth_email_total` – those emails per address, from all IPs (protects
      the mailbox)
    * `:contact` – contact form messages per client IP

  Counting sign-ins per address alone let anyone lock out an account by
  guessing wrong passwords for it (#126): with the client IP in the key, a
  bot only locks out itself.
  """
  use Hammer, backend: :ets

  @defaults [
    sign_in: {10, :timer.minutes(15)},
    sign_in_ip: {30, :timer.minutes(15)},
    auth_email: {3, :timer.minutes(15)},
    auth_email_total: {10, :timer.hours(1)},
    contact: {5, :timer.hours(1)}
  ]

  @doc "Counts a hit for `key` in `bucket`; `:ok` or `{:error, retry_after_ms}`."
  def check(bucket, key) do
    {limit, period} = limit(bucket)

    case hit("#{bucket}:#{key}", period, limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, retry_after}
    end
  end

  defp limit(bucket) do
    :mercator
    |> Application.get_env(:rate_limits, [])
    |> Keyword.get(bucket, Keyword.fetch!(@defaults, bucket))
  end
end
