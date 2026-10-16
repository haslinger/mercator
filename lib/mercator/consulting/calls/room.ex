defmodule Mercator.Consulting.Calls.Room do
  @moduledoc """
  The media relay (SFU) of one call (docs/video-design.md, section 4): a
  GenServer per conversation that owns one `ExWebRTC.PeerConnection` per
  participant and forwards the media of each to the other.

  A call has two participants, the customer and the consultant (#144),
  identified by their role. Each connection carries three channels in a fixed
  order, negotiated once when the participant joins: `:audio`, `:camera` and
  `:screen`. Turning the camera or a screen share on or off only replaces
  the track in the browser, so no renegotiation is needed. The server always
  makes the offer.

  Signaling goes to the participant's signal process (the LiveView, or a fake
  browser in tests) as `{:call_signal, conversation_id, message}`, where
  `message` is a JSON-ready map:

    * `%{"type" => "offer", "sdp" => …}` – answer it with `signal/3`
    * `%{"type" => "candidate", "candidate" => …}` – an ICE candidate
    * `%{"type" => "peer", "state" => "joined" | "left"}` – the other participant
    * `%{"type" => "state", "state" => …}` – the connection state, e.g. `"connected"`

  The room stops when the last participant leaves; a participant leaves when
  their signal process ends or their connection fails.
  """
  use GenServer, restart: :temporary

  require Logger

  alias ExRTCP.Packet.PayloadFeedback.PLI
  alias ExWebRTC.{ICECandidate, MediaStreamTrack, PeerConnection, SessionDescription}
  alias Mercator.Consulting.Calls

  @slots [:audio, :camera, :screen]
  @roles [:customer, :consultant]

  @doc "The channels of a connection, in the order of its transceivers."
  def slots, do: @slots

  def start_link(conversation_id) do
    GenServer.start_link(__MODULE__, conversation_id, name: via(conversation_id))
  end

  @doc "The room's name in `Mercator.Consulting.Calls.Registry`."
  def via(conversation_id),
    do: {:via, Registry, {Mercator.Consulting.Calls.Registry, conversation_id}}

  @doc """
  Joins `role` with `signal_pid` (which receives the signaling). A second
  join of the same role (e.g. after a reload) replaces the first.
  """
  def join(room, role, signal_pid) when role in @roles,
    do: GenServer.call(room, {:join, role, signal_pid})

  @doc "Passes a message from the participant's browser: an answer or an ICE candidate."
  def signal(room, role, message) when role in @roles,
    do: GenServer.call(room, {:signal, role, message})

  def leave(room, role) when role in @roles, do: GenServer.call(room, {:leave, role})

  @doc "Ends the call for everyone (the call was hung up)."
  def close(room), do: GenServer.call(room, :close)

  @doc "The roles in the call."
  def participants(room), do: GenServer.call(room, :participants)

  @impl true
  def init(conversation_id) do
    # the peer connections are linked: they end with the room, and a crashed
    # connection arrives as an exit message instead of taking the room down
    Process.flag(:trap_exit, true)
    {:ok, %{conversation_id: conversation_id, participants: %{}}}
  end

  @impl true
  def handle_call({:join, role, signal_pid}, _from, state) do
    state = remove(state, role)

    case connect(state.conversation_id, signal_pid) do
      {:ok, participant} ->
        notify_other(state, role, %{"type" => "peer", "state" => "joined"})
        {:reply, :ok, put_in(state.participants[role], participant)}

      {:error, reason} ->
        reply_after_leave(state, {:error, reason})
    end
  end

  def handle_call({:signal, role, message}, _from, state) do
    case Map.fetch(state.participants, role) do
      {:ok, participant} -> {:reply, apply_signal(participant.pc, message), state}
      :error -> {:reply, {:error, :not_joined}, state}
    end
  end

  def handle_call({:leave, role}, _from, state), do: reply_after_leave(remove(state, role), :ok)

  def handle_call(:participants, _from, state) do
    {:reply, Map.keys(state.participants), state}
  end

  def handle_call(:close, _from, state) do
    state = Enum.reduce(Map.keys(state.participants), state, &remove(&2, &1))
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info({:ex_webrtc, pc, message}, state) do
    case role_of(state, pc) do
      nil -> {:noreply, state}
      role -> handle_peer(message, role, state)
    end
  end

  # the participant's signal process (LiveView) ended
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Enum.find(state.participants, fn {_role, p} -> p.signal_ref == ref end) do
      {role, _participant} -> noreply_after_leave(remove(state, role))
      nil -> {:noreply, state}
    end
  end

  # a peer connection ended by itself (closed ones are removed already)
  def handle_info({:EXIT, pid, _reason}, state) do
    case role_of(state, pid) do
      nil -> {:noreply, state}
      role -> noreply_after_leave(remove(state, role, stopped?: true))
    end
  end

  @impl true
  def terminate(_reason, state) do
    for {_role, participant} <- state.participants, do: stop_peer(participant.pc)
    :ok
  end

  defp handle_peer({:ice_candidate, candidate}, role, state) do
    send_signal(state, role, %{
      "type" => "candidate",
      "candidate" => ICECandidate.to_json(candidate)
    })

    {:noreply, state}
  end

  defp handle_peer({:connection_state_change, connection_state}, role, state) do
    send_signal(state, role, %{"type" => "state", "state" => to_string(connection_state)})

    case connection_state do
      :connected ->
        # the other participant may already be sending video: this one needs
        # a keyframe to show a picture (asked for with the next packet, see
        # :rtp; before packets arrived the sender is not known yet)
        {:noreply,
         put_in(state.participants[role].needs_keyframe, MapSet.new([:camera, :screen]))}

      :failed ->
        Logger.warning("call #{state.conversation_id}: connection of #{role} failed")
        noreply_after_leave(remove(state, role))

      _other ->
        {:noreply, state}
    end
  end

  # media from `role`: forward it on the same channel to the other participant
  defp handle_peer({:rtp, track_id, nil, packet}, role, state) do
    with {:ok, from} <- Map.fetch(state.participants, role),
         {:ok, slot} <- Map.fetch(from.inbound, track_id),
         {:ok, to} <- Map.fetch(state.participants, other(role)) do
      PeerConnection.send_rtp(to.pc, Map.fetch!(to.outbound, slot), packet)

      if MapSet.member?(to.needs_keyframe, slot) do
        PeerConnection.send_pli(from.pc, track_id)

        {:noreply,
         update_in(state.participants[other(role)].needs_keyframe, &MapSet.delete(&1, slot))}
      else
        {:noreply, state}
      end
    else
      _not_forwarded -> {:noreply, state}
    end
  end

  # the other participant lost the picture of `role`'s track: ask the sender
  defp handle_peer({:rtcp, packets}, role, state) do
    with {:ok, receiver} <- Map.fetch(state.participants, role),
         {:ok, sender} <- Map.fetch(state.participants, other(role)) do
      for {track_id, %PLI{}} <- packets,
          {slot, ^track_id} <- receiver.outbound do
        PeerConnection.send_pli(sender.pc, inbound_track(sender, slot))
      end
    end

    {:noreply, state}
  end

  defp handle_peer(_message, _role, state), do: {:noreply, state}

  # A connection with the three channels, each sending (the other's media)
  # and receiving (this participant's), and the offer for the browser.
  defp connect(conversation_id, signal_pid) do
    case PeerConnection.start_link(Calls.peer_options()) do
      {:ok, pc} ->
        with {:error, reason} <- offer(conversation_id, pc, signal_pid) do
          stop_peer(pc)
          {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp offer(conversation_id, pc, signal_pid) do
    with :ok <- add_tracks(pc),
         {:ok, offer} <- PeerConnection.create_offer(pc),
         :ok <- PeerConnection.set_local_description(pc, offer) do
      transceivers = PeerConnection.get_transceivers(pc)
      slots = Enum.zip(@slots, transceivers)

      send(signal_pid, {:call_signal, conversation_id, SessionDescription.to_json(offer)})

      {:ok,
       %{
         pc: pc,
         signal_pid: signal_pid,
         signal_ref: Process.monitor(signal_pid),
         outbound: Map.new(slots, fn {slot, tr} -> {slot, tr.sender.track.id} end),
         inbound: Map.new(slots, fn {slot, tr} -> {tr.receiver.track.id, slot} end),
         needs_keyframe: MapSet.new()
       }}
    end
  end

  defp add_tracks(pc) do
    stream = MediaStreamTrack.generate_stream_id()

    Enum.reduce_while(@slots, :ok, fn slot, :ok ->
      kind = if slot == :audio, do: :audio, else: :video

      case PeerConnection.add_track(pc, MediaStreamTrack.new(kind, [stream])) do
        {:ok, _sender} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp apply_signal(pc, %{"type" => "answer"} = answer),
    do: PeerConnection.set_remote_description(pc, SessionDescription.from_json(answer))

  defp apply_signal(pc, %{"type" => "candidate", "candidate" => candidate}),
    do: PeerConnection.add_ice_candidate(pc, ICECandidate.from_json(candidate))

  defp apply_signal(_pc, _message), do: {:error, :unknown_signal}

  defp inbound_track(participant, slot) do
    Enum.find_value(participant.inbound, fn {track_id, s} -> if s == slot, do: track_id end)
  end

  defp remove(state, role, opts \\ []) do
    case Map.pop(state.participants, role) do
      {nil, _participants} ->
        state

      {participant, participants} ->
        Process.demonitor(participant.signal_ref, [:flush])
        unless opts[:stopped?], do: stop_peer(participant.pc)
        state = %{state | participants: participants}
        notify_other(state, role, %{"type" => "peer", "state" => "left"})
        state
    end
  end

  # an empty room ends
  defp reply_after_leave(%{participants: participants} = state, reply)
       when map_size(participants) == 0,
       do: {:stop, :normal, reply, state}

  defp reply_after_leave(state, reply), do: {:reply, reply, state}

  defp noreply_after_leave(%{participants: participants} = state)
       when map_size(participants) == 0,
       do: {:stop, :normal, state}

  defp noreply_after_leave(state), do: {:noreply, state}

  # closes the connection and ends its process
  defp stop_peer(pc) do
    PeerConnection.stop(pc)
  catch
    :exit, _already_gone -> :ok
  end

  defp role_of(state, pc) do
    Enum.find_value(state.participants, fn {role, p} -> if p.pc == pc, do: role end)
  end

  defp other(:customer), do: :consultant
  defp other(:consultant), do: :customer

  defp notify_other(state, role, message), do: send_signal(state, other(role), message)

  defp send_signal(state, role, message) do
    case Map.fetch(state.participants, role) do
      {:ok, participant} ->
        send(participant.signal_pid, {:call_signal, state.conversation_id, message})

      :error ->
        :ok
    end
  end
end
