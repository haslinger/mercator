defmodule Mercator.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email, in the user's language.
  """

  use AshAuthentication.Sender
  use MercatorWeb, :verified_routes
  use Gettext, backend: MercatorWeb.Gettext

  import Swoosh.Email

  alias Mercator.Accounts.AuthEmail
  alias Mercator.Mailer

  @impl true
  def send(user, token, _) do
    AuthEmail.in_locale(user, fn ->
      new()
      |> from(Mailer.default_from())
      |> to(to_string(user.email))
      |> subject(gettext("Reset your password"))
      |> AuthEmail.body([
        gettext("Click this link to set a new password:"),
        {:link, url(~p"/password-reset/#{token}")},
        gettext("If you have not asked for this, you can ignore this email.")
      ])
    end)
    |> Mailer.deliver_or_report(:password_reset, user.id)
  end
end
