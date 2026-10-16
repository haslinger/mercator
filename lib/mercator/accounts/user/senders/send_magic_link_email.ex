defmodule Mercator.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email: in the user's language, or for a new address in
  the language of the sign-in page.
  """

  use AshAuthentication.Sender
  use MercatorWeb, :verified_routes
  use Gettext, backend: MercatorWeb.Gettext

  import Swoosh.Email

  alias Mercator.Accounts.AuthEmail
  alias Mercator.Mailer

  @impl true
  def send(user_or_email, token, _) do
    # a user if the account exists, else just the address
    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    AuthEmail.in_locale(user_or_email, fn ->
      new()
      |> from(Mailer.default_from())
      |> to(to_string(email))
      |> subject(gettext("Your sign-in link"))
      |> AuthEmail.body([
        gettext("Hello %{email}, click this link to sign in:", email: to_string(email)),
        {:link, url(~p"/magic_link/#{token}")},
        gettext("If you have not asked for this, you can ignore this email.")
      ])
    end)
    |> Mailer.deliver_or_report(:magic_link, user_id(user_or_email))
  end

  defp user_id(%{id: id}), do: id
  defp user_id(_email), do: nil
end
