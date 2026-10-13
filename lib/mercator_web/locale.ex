defmodule MercatorWeb.Locale do
  @moduledoc """
  Determines the UI language for each request and LiveView.

  Order of precedence:

    1. `?locale=xx` in the URL (an explicit choice, remembered in the session)
    2. a choice remembered in the session
    3. the preferred language of the signed-in user
    4. the browser's `Accept-Language` header
    5. the default locale (`de`)

  The plug stores the resolved locale in the session under `"locale"`, so
  LiveViews (which cannot read request headers on mount) use the same one
  via `on_mount {MercatorWeb.Locale, :default}`.
  """
  @behaviour Plug

  import Plug.Conn

  @locales Gettext.known_locales(MercatorWeb.Gettext)
  @default_locale Gettext.get_locale(MercatorWeb.Gettext)

  @doc "The supported locales, as strings."
  def locales, do: @locales

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn = remember_choice(conn, supported(conn.params["locale"]))

    locale =
      get_session(conn, "chosen_locale") ||
        user_locale(conn.assigns[:current_user]) ||
        browser_locale(conn) ||
        @default_locale

    Gettext.put_locale(MercatorWeb.Gettext, locale)

    conn
    |> put_session("locale", locale)
    |> assign(:locale, locale)
  end

  def on_mount(:default, _params, session, socket) do
    locale = supported(session["locale"]) || @default_locale
    Gettext.put_locale(MercatorWeb.Gettext, locale)

    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end

  defp remember_choice(conn, nil), do: conn
  defp remember_choice(conn, locale), do: put_session(conn, "chosen_locale", locale)

  defp user_locale(%{locale: locale}) when not is_nil(locale), do: supported(to_string(locale))
  defp user_locale(_user), do: nil

  defp browser_locale(conn) do
    conn
    |> get_req_header("accept-language")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&(&1 |> String.split(";") |> hd() |> String.trim() |> String.downcase()))
    |> Enum.find_value(&supported(&1 |> String.split("-") |> hd()))
  end

  defp supported(locale) when locale in @locales, do: locale
  defp supported(_locale), do: nil
end
