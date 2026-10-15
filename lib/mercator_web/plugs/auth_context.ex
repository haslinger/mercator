defmodule MercatorWeb.Plugs.AuthContext do
  @moduledoc """
  Puts the client IP into the Ash context of the authentication routes
  (`/auth/…`, e.g. a sign-in form posted directly), so
  `Mercator.Accounts.Preparations.RateLimit` can count per IP (#126). The
  sign-in pages themselves do the same in `MercatorWeb.SignInLive`.
  """
  @behaviour Plug

  alias MercatorWeb.ClientIp

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    ip = ClientIp.resolve(conn.remote_ip, conn.req_headers)
    context = Ash.PlugHelpers.get_context(conn) || %{}
    Ash.PlugHelpers.set_context(conn, Map.put(context, :client_ip, ip))
  end
end
