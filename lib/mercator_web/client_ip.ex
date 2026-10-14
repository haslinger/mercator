defmodule MercatorWeb.ClientIp do
  @moduledoc """
  The visitor's IP address in a LiveView, e.g. for rate limiting (#87).

  Behind a reverse proxy the connection comes from the proxy; its
  `X-Forwarded-For` header is only believed when the connection comes
  from a trusted proxy (config `:trusted_proxies`, default the local
  host). Then the last address in the header that is not a trusted proxy
  is the client.
  """
  import Phoenix.LiveView, only: [get_connect_info: 2]

  @doc "The client IP as a string, or nil (e.g. on the static first render)."
  def from_socket(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> resolve(address, get_connect_info(socket, :x_headers) || [])
      _ -> nil
    end
  end

  @doc """
  The client IP from the peer address (tuple) and the `x-*` headers.

      iex> MercatorWeb.ClientIp.resolve({127, 0, 0, 1}, [{"x-forwarded-for", "203.0.113.7, 10.0.0.2"}])
      "10.0.0.2"
      iex> MercatorWeb.ClientIp.resolve({198, 51, 100, 1}, [{"x-forwarded-for", "203.0.113.7"}])
      "198.51.100.1"
  """
  def resolve(peer, headers) do
    peer = peer |> :inet.ntoa() |> to_string()

    if trusted?(peer) do
      headers
      |> Enum.filter(fn {name, _value} -> name == "x-forwarded-for" end)
      |> Enum.flat_map(fn {_name, value} -> String.split(value, ",") end)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&trusted?/1)
      |> List.last(peer)
    else
      peer
    end
  end

  defp trusted?(ip),
    do: ip in Application.get_env(:mercator, :trusted_proxies, ["127.0.0.1", "::1"])
end
