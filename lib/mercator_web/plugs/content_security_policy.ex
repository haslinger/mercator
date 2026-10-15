defmodule MercatorWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Sets the Content-Security-Policy (found by Sobelow, phase 8): scripts only
  from the shop itself, plus the one inline script of the root layout (the
  theme, which must run before the first paint), allowed by a nonce that is
  new for every request (`@conn.assigns.csp_nonce`).

  Styles allow `'unsafe-inline'`: templates use `style` attributes and the
  Markdown editor injects its styles. Pages may only be framed by the shop
  itself; forms only post to it. Payment providers are reached by
  redirects, which the policy does not restrict.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.encode64()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
  end

  @doc "The policy for a nonce."
  def policy(nonce) do
    Enum.join(
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob:",
        "font-src 'self' data:",
        "connect-src 'self'",
        "worker-src 'self'",
        "frame-src 'self'",
        "frame-ancestors 'self'",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ],
      "; "
    )
  end
end
