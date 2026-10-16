defmodule Mercator.Accounts.AuthEmail do
  @moduledoc """
  Shared parts of the authentication emails (magic link, password reset,
  confirmation): the language and a plain text and HTML body.

  A known user gets the email in their language (`locale`); a new address
  (magic link for someone without an account) in the language of the page
  that asked for it, i.e. the current Gettext locale.
  """

  import Swoosh.Email

  @doc "Runs `fun` in the language of the user, or the current one for a bare address."
  def in_locale(%{locale: locale}, fun) when not is_nil(locale),
    do: Gettext.with_locale(MercatorWeb.Gettext, to_string(locale), fun)

  def in_locale(_email, fun), do: fun.()

  @doc """
  Sets text and HTML body from paragraphs; a paragraph is a string or
  `{:link, url}`. Texts are escaped in the HTML.
  """
  def body(email, paragraphs) do
    email
    |> text_body(Enum.map_join(paragraphs, "\n\n", &text/1) <> "\n\n" <> Mercator.Brand.name())
    |> html_body(Enum.map_join(paragraphs, "\n", &html/1))
  end

  defp text({:link, url}), do: url
  defp text(paragraph), do: paragraph

  defp html({:link, url}), do: ~s(<p><a href="#{escape(url)}">#{escape(url)}</a></p>)
  defp html(paragraph), do: "<p>#{escape(paragraph)}</p>"

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
