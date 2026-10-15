defmodule MercatorWeb.ClientIpTest do
  # sets :trusted_proxies globally
  use ExUnit.Case, async: false

  alias MercatorWeb.ClientIp

  setup do
    previous = Application.get_env(:mercator, :trusted_proxies)
    Application.put_env(:mercator, :trusted_proxies, ["172.16.0.0/12"])

    on_exit(fn ->
      if previous,
        do: Application.put_env(:mercator, :trusted_proxies, previous),
        else: Application.delete_env(:mercator, :trusted_proxies)
    end)
  end

  # the home server (#126): Caddy -> Docker gateway -> app listening on ::
  test "trusts the Docker gateway when it arrives IPv4-mapped" do
    gateway = {0, 0, 0, 0, 0, 0xFFFF, 0xAC14, 0x0001}

    assert ClientIp.resolve(gateway, [{"x-forwarded-for", "203.0.113.7"}]) == "203.0.113.7"
  end

  test "reports IPv4-mapped clients and header entries as IPv4" do
    assert ClientIp.resolve({0, 0, 0, 0, 0, 0xFFFF, 0xC633, 0x6401}, []) == "198.51.100.1"

    gateway = {172, 20, 0, 1}
    headers = [{"x-forwarded-for", "::ffff:203.0.113.7"}]
    assert ClientIp.resolve(gateway, headers) == "203.0.113.7"
  end

  test "does not trust other peers" do
    assert ClientIp.resolve({198, 51, 100, 1}, [{"x-forwarded-for", "203.0.113.7"}]) ==
             "198.51.100.1"
  end
end
