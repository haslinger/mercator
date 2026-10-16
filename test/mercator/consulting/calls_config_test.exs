defmodule Mercator.Consulting.CallsConfigTest do
  # changes the application environment, so not async
  use ExUnit.Case, async: false

  alias Mercator.Consulting.Calls

  setup do
    previous = Application.get_env(:mercator, Calls)
    on_exit(fn -> restore(previous) end)
  end

  defp restore(nil), do: Application.delete_env(:mercator, Calls)
  defp restore(previous), do: Application.put_env(:mercator, Calls, previous)

  test "one codec each, ephemeral ports and no ICE servers by default" do
    Application.delete_env(:mercator, Calls)

    assert Calls.peer_options() == [ice_servers: [], audio_codecs: [:opus], video_codecs: [:vp8]]
  end

  test "the configured port range and STUN servers" do
    Application.put_env(:mercator, Calls,
      ice_port_range: 50_000..50_049,
      ice_servers: [%{urls: "stun:stun.example.org:3478"}]
    )

    options = Calls.peer_options()
    assert options[:ice_port_range] == 50_000..50_049
    assert options[:ice_servers] == [%{urls: "stun:stun.example.org:3478"}]
  end

  test "the public host stands in for the container's IPv4 address" do
    Application.put_env(:mercator, Calls, public_host: "localhost")
    mapper = Calls.peer_options()[:host_to_srflx_ip_mapper]

    assert mapper.({172, 30, 0, 10}) == {127, 0, 0, 1}
    assert mapper.({127, 0, 0, 1}) == nil
    assert mapper.({0, 0, 0, 0, 0, 0, 0, 1}) == nil
  end

  test "an unknown public host is left out (and logged)" do
    Application.put_env(:mercator, Calls, public_host: "no-such-host.invalid")

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        refute Keyword.has_key?(Calls.peer_options(), :host_to_srflx_ip_mapper)
      end)

    assert log =~ "not resolved"
  end
end
