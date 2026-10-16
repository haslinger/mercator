defmodule Mercator.Accounts.Preparations.RateLimit do
  @moduledoc """
  Limits authentication attempts (#87, #126, `Mercator.RateLimit`), so
  passwords cannot be guessed at speed and no one's mailbox can be flooded:

    * `bucket: :sign_in` – per email address and client IP, and per client IP
      for all addresses
    * `bucket: :auth_email` (password reset, magic link) – per address and
      client IP, and per address in total

  The client IP comes from the action context (`:client_ip`), set by
  `MercatorWeb.SignInLive` and `MercatorWeb.Plugs.AuthContext`. Keyed by IP,
  failed attempts by a bot block only the bot, not the account's owner.
  Without an IP only the address is counted. Every limit reached is reported
  as an incident, one per bucket and IP, and logged as a warning (#136) in a
  fixed format for tools like fail2ban, without the email address:

      rate limit reached: bucket=sign_in_ip ip=203.0.113.7

  Works for read and generic actions.
  """
  use Ash.Resource.Preparation
  use Gettext, backend: MercatorWeb.Gettext

  require Logger

  alias Mercator.Operations.Incidents

  @impl true
  def supports(_opts), do: [Ash.Query, Ash.ActionInput]

  # Counted in a before-action hook, i.e. only when the action runs: the
  # sign-in forms validate on every keystroke, which builds the query and
  # runs preparations, so counting here would count typing as attempts.
  @impl true
  def prepare(subject, opts, _context) do
    before_action(subject, &check(&1, opts[:bucket]), prepend?: true)
  end

  defp check(subject, bucket) do
    email = subject |> argument(:email) |> to_string() |> String.downcase()
    ip = subject.context[:client_ip]

    bucket
    |> checks(email, ip)
    |> Enum.find(fn {bucket, key} -> Mercator.RateLimit.check(bucket, key) != :ok end)
    |> case do
      nil ->
        subject

      {bucket, _key} ->
        report(bucket, email, ip)

        add_error(subject,
          field: :email,
          message: dgettext_noop("errors", "too many attempts, please try again later")
        )
    end
  end

  defp checks(:sign_in, email, nil), do: [{:sign_in, email}]
  defp checks(:sign_in, email, ip), do: [{:sign_in, "#{email}|#{ip}"}, {:sign_in_ip, ip}]

  defp checks(:auth_email, email, nil), do: [{:auth_email, email}, {:auth_email_total, email}]

  defp checks(:auth_email, email, ip),
    do: [{:auth_email, "#{email}|#{ip}"}, {:auth_email_total, email}]

  defp report(bucket, email, ip) do
    Logger.warning("rate limit reached: bucket=#{bucket} ip=#{ip || "unknown"}")

    Incidents.in_shop_locale(fn ->
      Incidents.report(%{
        kind: :other,
        title:
          gettext("Rate limit reached: %{what} from %{ip}",
            what: what(bucket),
            ip: ip || gettext("unknown IP")
          ),
        description: gettext("Last attempt for %{email}.", email: email),
        details: "bucket #{bucket}, client IP #{ip || "unknown"}",
        fingerprint: "rate_limit:#{bucket}:#{ip || email}"
      })
    end)
  end

  defp what(bucket) when bucket in [:sign_in, :sign_in_ip], do: gettext("sign-in attempts")
  defp what(_bucket), do: gettext("sign-in emails")

  defp argument(%Ash.Query{} = query, name), do: Ash.Query.get_argument(query, name)
  defp argument(%Ash.ActionInput{} = input, name), do: Ash.ActionInput.get_argument(input, name)

  defp before_action(%Ash.Query{} = query, fun, opts),
    do: Ash.Query.before_action(query, fun, opts)

  defp before_action(%Ash.ActionInput{} = input, fun, opts),
    do: Ash.ActionInput.before_action(input, fun, opts)

  defp add_error(%Ash.Query{} = query, error), do: Ash.Query.add_error(query, error)
  defp add_error(%Ash.ActionInput{} = input, error), do: Ash.ActionInput.add_error(input, error)
end
