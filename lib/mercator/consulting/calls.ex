defmodule Mercator.Consulting.Calls do
  @moduledoc """
  Audio and video calls in advice conversations (phase 10,
  docs/video-design.md): the call records (`Mercator.Consulting.Call`),
  the media relay of a call (`Mercator.Consulting.Calls.Room`) and its
  WebRTC settings.

  The consultant calls and hangs up through `Mercator.Consulting.Desk`, the
  customer answers through `Mercator.Consulting.Conversations`; both end in
  `finish/2` here. Who may join the media is decided by the callers of
  `join/3` (the LiveViews); the room only relays.

  Changes are broadcast as `{:call, call}` on `"conversation:<id>"` (the
  customer) and on `"desk"` (every desk follows its consultant's call, also
  while another conversation is selected, #150), and a customer's request
  for a call (#141) as `{:call_requested, conversation_id}` on `"desk"`.

  Configuration (`config :mercator, Mercator.Consulting.Calls`, set from the
  environment in `config/runtime.exs`):

    * `:ice_servers` – STUN/TURN servers, e.g. `[%{urls: "stun:stun.example.org:3478"}]`
    * `:ice_port_range` – the UDP ports for media, e.g. `50000..50049`
      (published by Docker with the same numbers); ephemeral ports if unset
    * `:public_host` – the server's public host name or IP address. Inside a
      container the app only knows its container address; with this the
      browsers are offered the public one (resolved for each call, so a
      changing home IP behind DynDNS is followed)
  """
  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query
  require Logger

  alias Mercator.Consulting.{Call, Conversation, Conversations}
  alias Mercator.Consulting.Calls.Room
  alias Mercator.Operations.Incidents

  @doc "How long a call rings before it counts as missed, in seconds."
  def ring_seconds, do: Application.get_env(:mercator, :call_ring_seconds, 45)

  @doc "The conversation's ringing or active call, or nil (not authorized: callers check access)."
  def open_call(conversation_id) do
    Call
    |> Ash.Query.filter(conversation_id == ^conversation_id and state in [:ringing, :active])
    |> Ash.read_one!(authorize?: false)
  end

  @doc "The consultant's ringing or active call, or nil: a consultant is in one call at a time."
  def consultant_call(consultant_id) do
    Call
    |> Ash.Query.filter(consultant_id == ^consultant_id and state in [:ringing, :active])
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  @doc """
  Ends a call with a reason (`Call` `end_reason`): records it, ends the media
  and writes the outcome into the chat ("Call, 14:05–14:20", "Missed call",
  …). A call that has already ended is left as it is (`{:error, :ended}`).
  """
  def finish(%Call{state: :ended}, _reason), do: {:error, :ended}

  def finish(%Call{} = call, reason) do
    with {:ok, call} <-
           Ash.update(call, %{end_reason: reason}, action: :finish, authorize?: false) do
      :telemetry.execute([:mercator, :call, :stop], %{duration: duration(call)}, %{reason: reason})

      with_room(call.conversation_id, &Room.close/1)
      conversation = Ash.get!(Conversation, call.conversation_id, authorize?: false)
      Conversations.create_message(conversation, %{sender_kind: :system, body: summary(call)})
      broadcast(call)
      {:ok, call}
    end
  end

  # seconds talked; 0 for a call that was not answered
  defp duration(%Call{answered_at: nil}), do: 0
  defp duration(%Call{answered_at: from, ended_at: to}), do: DateTime.diff(to, from)

  @doc """
  The media connection of `role` failed (reported by the room): the call
  ends as failed, and an incident (#105) keeps what ICE tried, so blocked
  UDP ports or a missing public address show up.
  """
  def connection_failed(%Call{} = call, role, details) do
    with {:ok, call} <- finish(call, :failed) do
      Incidents.in_shop_locale(fn ->
        Incidents.report(%{
          kind: :other,
          title: gettext("A call could not be connected"),
          description: failed_description(role),
          details: details,
          conversation_id: call.conversation_id,
          fingerprint: "call_failed:#{call.id}"
        })
      end)

      {:ok, call}
    end
  end

  defp failed_description(:customer),
    do:
      gettext(
        "The customer's connection to the media server failed (blocked UDP ports, a missing public address, or a network without UDP)."
      )

  defp failed_description(:consultant),
    do:
      gettext(
        "The consultant's connection to the media server failed (blocked UDP ports, a missing public address, or a network without UDP)."
      )

  @doc "The chat line for an ended call."
  def summary(%Call{end_reason: :completed} = call) do
    times = %{from: clock(call.answered_at), to: clock(call.ended_at)}

    if call.video,
      do: gettext("Video call, %{from}–%{to}", times),
      else: gettext("Call, %{from}–%{to}", times)
  end

  def summary(%Call{end_reason: :declined}), do: gettext("Call declined")
  def summary(%Call{end_reason: :failed}), do: gettext("The call could not be connected.")
  def summary(%Call{}), do: gettext("Missed call")

  defp clock(datetime), do: datetime |> Mercator.Clock.local() |> Calendar.strftime("%H:%M")

  @doc false
  def broadcast(%Call{} = call) do
    Conversations.broadcast("conversation:#{call.conversation_id}", {:call, call})
    Conversations.broadcast("desk", {:call, call})
  end

  @doc """
  Joins `role` (`:customer` or `:consultant`) to the call of a conversation,
  starting its room if needed. `signal_pid` receives the signaling messages
  (see `Room`).
  """
  def join(conversation_id, role, signal_pid \\ self()) do
    with {:ok, room} <- ensure_room(conversation_id) do
      Room.join(room, role, signal_pid)
    end
  end

  @doc "Passes the browser's answer or an ICE candidate to the room."
  def signal(conversation_id, role, message),
    do: with_room(conversation_id, &Room.signal(&1, role, message))

  def leave(conversation_id, role), do: with_room(conversation_id, &Room.leave(&1, role))

  @doc """
  A participant starts or stops sharing their screen (#143): the other is
  told (and stops their own share, one at a time), and the call notes it.
  """
  def screen_share(%Call{} = call, role, on?) when is_boolean(on?) do
    if on?, do: Ash.update(call, %{screen_shared: true}, action: :note_media, authorize?: false)
    message = %{"type" => "screen", "state" => if(on?, do: "on", else: "off")}
    with_room(call.conversation_id, &Room.relay(&1, role, message))
  end

  @doc "The roles in the conversation's call, `[]` if there is none."
  def participants(conversation_id) do
    case with_room(conversation_id, &Room.participants/1) do
      {:error, :no_call} -> []
      roles -> roles
    end
  end

  @doc "The options for each `ExWebRTC.PeerConnection` of a room."
  def peer_options do
    config = Application.get_env(:mercator, __MODULE__, [])

    [
      ice_servers: Keyword.get(config, :ice_servers, []),
      # one codec each, so packets can be forwarded unchanged between browsers
      audio_codecs: [:opus],
      video_codecs: [:vp8]
    ]
    |> put_if(:ice_port_range, Keyword.get(config, :ice_port_range))
    |> put_if(:host_to_srflx_ip_mapper, public_address(Keyword.get(config, :public_host)))
  end

  # the container's IPv4 address stands for the public one (port forwarding
  # keeps the port numbers)
  defp public_address(nil), do: nil

  defp public_address(host) do
    case :inet.getaddr(String.to_charlist(host), :inet) do
      {:ok, public_ip} ->
        fn
          {127, _, _, _} -> nil
          {_, _, _, _} -> public_ip
          _ipv6 -> nil
        end

      {:error, reason} ->
        Logger.warning("calls: public host #{inspect(host)} not resolved (#{inspect(reason)})")
        nil
    end
  end

  defp put_if(options, _key, nil), do: options
  defp put_if(options, key, value), do: Keyword.put(options, key, value)

  defp ensure_room(conversation_id) do
    case DynamicSupervisor.start_child(
           Mercator.Consulting.Calls.Supervisor,
           {Room, conversation_id}
         ) do
      {:ok, room} -> {:ok, room}
      {:error, {:already_started, room}} -> {:ok, room}
      {:error, reason} -> {:error, reason}
    end
  end

  # a room that has just ended may still be registered for a moment
  defp with_room(conversation_id, fun) do
    case Registry.lookup(Mercator.Consulting.Calls.Registry, conversation_id) do
      [{room, _value}] ->
        try do
          fun.(room)
        catch
          :exit, {:noproc, _} -> {:error, :no_call}
          :exit, {:normal, _} -> {:error, :no_call}
        end

      [] ->
        {:error, :no_call}
    end
  end
end
