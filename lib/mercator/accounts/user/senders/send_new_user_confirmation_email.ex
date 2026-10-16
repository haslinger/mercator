defmodule Mercator.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address, in the
  user's language.
  """

  use AshAuthentication.Sender
  use MercatorWeb, :verified_routes
  use Gettext, backend: MercatorWeb.Gettext

  import Swoosh.Email

  alias Mercator.Accounts.AuthEmail
  alias Mercator.Mailer

  @impl true
  def send(user, token, opts) do
    AuthEmail.in_locale(user, fn ->
      new()
      |> from(Mailer.default_from())
      |> to(to_string(user.email))
      |> subject(subject(opts))
      |> AuthEmail.body(paragraphs(url(~p"/confirm_new_user/#{token}"), opts))
    end)
    |> Mailer.deliver_or_report(:confirmation, user.id)
  end

  # `opts[:confirmation_type]` is `:identity_link` when an OAuth2/OIDC
  # sign-in whose email matches this already-registered account is asking
  # to be linked (the strategy's `on_untrusted_email_match :confirm`).
  # Confirming grants that provider login access to this account, so make
  # the copy unambiguous about who is asking and what it does.
  defp subject(opts) do
    case opts[:confirmation_type] do
      :identity_link ->
        gettext("Confirm linking your %{provider} login", provider: to_string(opts[:provider]))

      _ ->
        gettext("Confirm your email address")
    end
  end

  defp paragraphs(url, opts) do
    case opts[:confirmation_type] do
      :identity_link ->
        [
          gettext(
            "Someone signed in with %{provider} using your email address and wants to link it to your account.",
            provider: to_string(opts[:provider])
          ),
          gettext("If this was you, confirm here:"),
          {:link, url},
          gettext("If it wasn't you, ignore this email - nothing has changed.")
        ]

      _ ->
        [gettext("Click this link to confirm your email address:"), {:link, url}]
    end
  end
end
