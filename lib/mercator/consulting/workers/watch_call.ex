defmodule Mercator.Consulting.Workers.WatchCall do
  @moduledoc """
  Watches a call (phase 10) so none stays open by mistake:

    * still ringing after `Calls.ring_seconds/0`: the call ends as missed;
    * active, but nobody is in its media room any more (both closed their
      tabs, or the room is gone after a restart): it ends as completed;
    * otherwise it looks again a minute later, while the call lasts.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Mercator.Consulting.{Call, Calls}

  # a call that was just answered gets time to connect
  @grace_seconds 30

  @doc "Schedules the first look at a call that has just started ringing."
  def enqueue(call_id),
    do: %{call_id: call_id} |> new(schedule_in: Calls.ring_seconds()) |> Oban.insert!()

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"call_id" => id}}) do
    case Ash.get(Call, id, authorize?: false) do
      {:ok, %Call{state: :ringing} = call} -> finish(call, :missed)
      {:ok, %Call{state: :active} = call} -> watch(call)
      _ended_or_gone -> :ok
    end
  end

  defp watch(call) do
    connecting? = DateTime.diff(DateTime.utc_now(), call.answered_at) < @grace_seconds

    if Calls.participants(call.conversation_id) == [] and not connecting?,
      do: finish(call, :completed),
      else: {:snooze, 60}
  end

  defp finish(call, reason) do
    case Calls.finish(call, reason) do
      {:ok, _call} -> :ok
      # ended meanwhile by a hang-up
      {:error, _} -> :ok
    end
  end
end
