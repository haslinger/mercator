defmodule Mercator.Accounts.AuthEmailTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Accounts.User.Senders.{
    SendMagicLinkEmail,
    SendNewUserConfirmationEmail,
    SendPasswordResetEmail
  }

  defp in_english(user), do: Ash.Seed.update!(user, %{locale: :en})

  test "the password reset email is in the user's language" do
    user = user_fixture()

    SendPasswordResetEmail.send(user, "tok", [])

    assert_received {:email,
                     %{subject: "Passwort zurücksetzen", html_body: html, text_body: text}}

    assert html =~ ~r{href="http://[^"]+/password-reset/tok"}
    assert text =~ "neues Passwort"

    SendPasswordResetEmail.send(in_english(user), "tok", [])
    assert_received {:email, %{subject: "Reset your password"}}
  end

  test "the magic link email is in the user's language" do
    user = user_fixture() |> in_english()

    SendMagicLinkEmail.send(user, "tok", [])
    assert_received {:email, %{subject: "Your sign-in link", html_body: html}}
    assert html =~ "/magic_link/tok"
  end

  test "the magic link to a new address is in the page's language and escaped" do
    Gettext.with_locale(MercatorWeb.Gettext, "en", fn ->
      SendMagicLinkEmail.send("a<b>@example.com", "tok", [])
    end)

    assert_received {:email, %{subject: "Your sign-in link", html_body: html}}
    assert html =~ "a&lt;b&gt;@example.com"

    SendMagicLinkEmail.send("neu@example.com", "tok", [])
    assert_received {:email, %{subject: "Ihr Anmeldelink"}}
  end

  test "the confirmation email is in the user's language" do
    user = user_fixture()

    SendNewUserConfirmationEmail.send(user, "tok", [])
    assert_received {:email, %{subject: "Bestätigen Sie Ihre E-Mail-Adresse"}}

    SendNewUserConfirmationEmail.send(in_english(user), "tok",
      confirmation_type: :identity_link,
      provider: :google
    )

    assert_received {:email, %{subject: "Confirm linking your google login"}}
  end
end
