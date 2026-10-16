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
  """
  use Gettext, backend: MercatorWeb.Gettext

  require Ash.Query

  alias Mercator.Consulting.{Call, Conversation, Conversations}
  alias Mercator.Consulting.Calls.Room

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
      with_room(call.conversation_id, &Room.close/1)
      conversation = Ash.get!(Conversation, call.conversation_id, authorize?: false)
      Conversations.create_message(conversation, %{sender_kind: :system, body: summary(call)})
      broadcast(call)
      {:ok, call}
    end
  end

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
