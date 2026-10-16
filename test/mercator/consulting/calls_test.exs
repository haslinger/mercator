defmodule Mercator.Consulting.CallsTest do
  # Two browsers, played by ExWebRTC peer connections, call each other
  # through the media relay (docs/video-design.md, section 8)
  use ExUnit.Case, async: true

  # closing connections makes the ICE library log warnings
  @moduletag :capture_log

  alias Mercator.Consulting.Calls
  alias Mercator.FakeBrowser

  @timeout 10_000

  defp call do
    id = Ecto.UUID.generate()
    {:ok, customer} = FakeBrowser.start_link(id, :customer)
    {:ok, consultant} = FakeBrowser.start_link(id, :consultant)

    assert_receive {:browser, :customer, :connected}, @timeout
    assert_receive {:browser, :consultant, :connected}, @timeout

    %{id: id, customer: customer, consultant: consultant}
  end

  test "forwards audio, camera and screen to the other participant, both ways" do
    %{customer: customer, consultant: consultant} = call()

    :ok = FakeBrowser.send_media(customer, :audio, "Grüß Gott")
    :ok = FakeBrowser.send_media(customer, :camera, "camera frame")
    :ok = FakeBrowser.send_media(consultant, :screen, "screen frame")

    assert_receive {:browser, :consultant, :media, :audio, "Grüß Gott"}, @timeout
    assert_receive {:browser, :consultant, :media, :camera, "camera frame"}, @timeout
    assert_receive {:browser, :customer, :media, :screen, "screen frame"}, @timeout
    refute_received {:browser, :customer, :media, :audio, "Grüß Gott"}
  end

  test "asks the sender for a keyframe for a newly connected participant, once" do
    %{customer: customer} = call()

    :ok = FakeBrowser.send_media(customer, :camera, "frame 1")
    assert_receive {:browser, :customer, :keyframe_request, :camera}, @timeout

    :ok = FakeBrowser.send_media(customer, :camera, "frame 2")
    assert_receive {:browser, :consultant, :media, :camera, "frame 2"}, @timeout
    refute_received {:browser, :customer, :keyframe_request, :camera}
  end

  test "tells the other participant who joins and leaves; the room ends with the last" do
    %{id: id, customer: customer, consultant: consultant} = call()

    assert_receive {:browser, :customer, :signal, %{"type" => "peer", "state" => "joined"}}
    assert Enum.sort(Calls.participants(id)) == [:consultant, :customer]

    [{room, _}] = Registry.lookup(Mercator.Consulting.Calls.Registry, id)
    ref = Process.monitor(room)

    # a browser that goes away (tab closed, LiveView gone) leaves the call
    GenServer.stop(consultant)

    assert_receive {:browser, :customer, :signal, %{"type" => "peer", "state" => "left"}},
                   @timeout

    assert Calls.participants(id) == [:customer]

    :ok = Calls.leave(id, :customer)
    assert_receive {:DOWN, ^ref, :process, ^room, :normal}
    assert Calls.participants(id) == []
    GenServer.stop(customer)
  end

  test "a participant joining again replaces the earlier connection" do
    %{id: id, consultant: consultant} = call()

    {:ok, _again} = FakeBrowser.start_link(id, :consultant)
    assert_receive {:browser, :consultant, :connected}, @timeout
    assert Enum.sort(Calls.participants(id)) == [:consultant, :customer]
    assert Process.alive?(consultant)
  end

  test "signals for a call that does not exist or a participant not in it are refused" do
    assert Calls.signal(Ecto.UUID.generate(), :customer, %{"type" => "answer"}) ==
             {:error, :no_call}

    %{id: id} = call()
    assert Calls.signal(id, :customer, %{"type" => "bogus"}) == {:error, :unknown_signal}
  end
end
