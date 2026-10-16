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
end
