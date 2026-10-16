defmodule Mercator.FakeBrowser do
  @moduledoc """
  A browser in a call, played by an `ExWebRTC.PeerConnection` (video advice,
  phase 10): joins the call of a conversation, answers the room's offer,
  sends RTP packets on its audio, camera or screen track and reports what it
  receives to the test process:

    * `{:browser, role, :connected}`
    * `{:browser, role, :media, slot, payload}` – a packet from the other participant
    * `{:browser, role, :keyframe_request, slot}` – the room asked for a keyframe
    * `{:browser, role, :signal, message}` – peer and state messages from the room
  """
  use GenServer

  alias ExRTCP.Packet.PayloadFeedback.PLI
  alias ExWebRTC.{ICECandidate, MediaStreamTrack, PeerConnection, SessionDescription}
  alias Mercator.Consulting.Calls

  def start_link(conversation_id, role, test_pid \\ self()) do
    GenServer.start_link(__MODULE__, {conversation_id, role, test_pid})
  end

  @doc "Sends one RTP packet with `payload` on the browser's track for `slot`."
  def send_media(browser, slot, payload),
    do: GenServer.call(browser, {:send_media, slot, payload})

  @impl true
  def init({conversation_id, role, test_pid}) do
    {:ok, pc} = PeerConnection.start_link(audio_codecs: [:opus], video_codecs: [:vp8])

    state = %{
      conversation_id: conversation_id,
      role: role,
      test_pid: test_pid,
      pc: pc,
      tracks: %{},
      inbound: %{},
      sequence: 0
    }

    :ok = Calls.join(conversation_id, role)
    {:ok, state}
  end

  @impl true
  def handle_call({:send_media, slot, payload}, _from, state) do
    sequence = state.sequence + 1

    packet =
      ExRTP.Packet.new(payload,
        sequence_number: sequence,
        timestamp: sequence * 960,
        marker: true
      )

    PeerConnection.send_rtp(state.pc, Map.fetch!(state.tracks, slot), packet)
    {:reply, :ok, %{state | sequence: sequence}}
  end

  @impl true
  def handle_info({:call_signal, _id, %{"type" => "offer"} = offer}, state) do
    :ok = PeerConnection.set_remote_description(state.pc, SessionDescription.from_json(offer))

    # one track per channel, on the transceivers of the offer, in their order
    transceivers = PeerConnection.get_transceivers(state.pc)

    {tracks, inbound} =
      Calls.Room.slots()
      |> Enum.zip(transceivers)
      |> Enum.reduce({%{}, %{}}, fn {slot, tr}, {tracks, inbound} ->
        track = MediaStreamTrack.new(tr.kind)
        :ok = PeerConnection.set_transceiver_direction(state.pc, tr.id, :sendrecv)
        :ok = PeerConnection.replace_track(state.pc, tr.sender.id, track)
        {Map.put(tracks, slot, track.id), Map.put(inbound, tr.receiver.track.id, slot)}
      end)

    {:ok, answer} = PeerConnection.create_answer(state.pc)
    :ok = PeerConnection.set_local_description(state.pc, answer)
    :ok = Calls.signal(state.conversation_id, state.role, SessionDescription.to_json(answer))
    {:noreply, %{state | tracks: tracks, inbound: inbound}}
  end

  def handle_info({:call_signal, _id, %{"type" => "candidate", "candidate" => candidate}}, state) do
    :ok = PeerConnection.add_ice_candidate(state.pc, ICECandidate.from_json(candidate))
    {:noreply, state}
  end

  def handle_info({:call_signal, _id, message}, state) do
    report(state, {:signal, message})
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, {:ice_candidate, candidate}}, state) do
    message = %{"type" => "candidate", "candidate" => ICECandidate.to_json(candidate)}
    :ok = Calls.signal(state.conversation_id, state.role, message)
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, {:connection_state_change, :connected}}, state) do
    report(state, :connected)
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, {:rtp, track_id, nil, packet}}, state) do
    report(state, {:media, Map.get(state.inbound, track_id), packet.payload})
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, {:rtcp, packets}}, state) do
    for {track_id, %PLI{}} <- packets,
        {slot, ^track_id} <- state.tracks,
        do: report(state, {:keyframe_request, slot})

    {:noreply, state}
  end

  def handle_info({:ex_webrtc, _pc, _message}, state), do: {:noreply, state}

  defp report(state, event) when is_tuple(event),
    do: send(state.test_pid, List.to_tuple([:browser, state.role | Tuple.to_list(event)]))

  defp report(state, event), do: send(state.test_pid, {:browser, state.role, event})
end
