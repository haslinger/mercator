defmodule Mercator.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use MercatorWeb, :verified_routes

  import Swoosh.Email

  alias Mercator.Mailer

  @impl true
  def send(user, token, _) do
    new()
    |> from(Mailer.default_from())
    |> to(to_string(user.email))
    |> subject("Reset your password")
    |> html_body(body(token: token))
    |> Mailer.deliver_or_report(:password_reset, user.id)
  end

  defp body(params) do
    url = url(~p"/password-reset/#{params[:token]}")

    """
    <p>Click this link to reset your password:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
