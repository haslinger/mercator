defmodule Mercator.Consulting.Calls do
  @moduledoc """
  Audio and video calls in advice conversations (phase 10,
  docs/video-design.md): starting and finding the media relay of a call
  (`Mercator.Consulting.Calls.Room`) and its WebRTC settings.

  Who may call is decided by the caller of these functions (the LiveViews,
  with the `Call` resource's policies); the room only relays.

  Configuration (`config :mercator, Mercator.Consulting.Calls`, set from the
  environment in `config/runtime.exs`):

    * `:ice_servers` – STUN/TURN servers, e.g. `[%{urls: "stun:stun.example.org:3478"}]`
    * `:ice_port_range` – the UDP ports for media, e.g. `50000..50049`
      (published by Docker with the same numbers); ephemeral ports if unset
  """
  alias Mercator.Consulting.Calls.Room

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
