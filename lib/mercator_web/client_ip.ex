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

  defp trusted?(ip) do
    :mercator
    |> Application.get_env(:trusted_proxies, ["127.0.0.1", "::1"])
    |> Enum.any?(&matches?(ip, &1))
  end

  @doc """
  Whether an address matches a trusted proxy entry: an address, or a
  network such as `172.16.0.0/12` (Docker's networks, where the reverse
  proxy's address can change).

      iex> MercatorWeb.ClientIp.matches?("172.18.0.1", "172.16.0.0/12")
      true
      iex> MercatorWeb.ClientIp.matches?("172.32.0.1", "172.16.0.0/12")
      false
      iex> MercatorWeb.ClientIp.matches?("::1", "::1")
      true
  """
  def matches?(ip, entry) do
    case String.split(entry, "/") do
      [^ip] -> true
      [network, bits] -> in_network?(ip, network, bits)
      _other -> false
    end
  end

  defp in_network?(ip, network, bits) do
    with {:ok, address} <- :inet.parse_address(String.to_charlist(ip)),
         {:ok, network} <- :inet.parse_address(String.to_charlist(network)),
         true <- tuple_size(address) == tuple_size(network),
         size = if(tuple_size(address) == 4, do: 8, else: 16),
         {bits, ""} when bits in 0..(size * tuple_size(address))//1 <- Integer.parse(bits) do
      prefix(address, size, bits) == prefix(network, size, bits)
    else
      _ -> false
    end
  end

  # the first `bits` bits of an address
  defp prefix(address, size, bits) do
    binary = address |> Tuple.to_list() |> Enum.map(&<<&1::size(size)>>) |> IO.iodata_to_binary()
    <<prefix::bitstring-size(^bits), _rest::bitstring>> = binary
    prefix
  end
end
