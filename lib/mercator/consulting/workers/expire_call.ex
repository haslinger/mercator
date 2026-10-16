defmodule Mercator.Consulting.Workers.ExpireCall do
  @moduledoc """
  A call nobody answered (phase 10): after `Calls.ring_seconds/0` a call
  that is still ringing ends as missed.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Mercator.Consulting.{Call, Calls}

  @doc "Schedules the check for a call that has just started ringing."
  def enqueue(call_id),
    do: %{call_id: call_id} |> new(schedule_in: Calls.ring_seconds()) |> Oban.insert!()

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"call_id" => id}}) do
    case Ash.get(Call, id, authorize?: false) do
      {:ok, %Call{state: :ringing} = call} ->
        with {:ok, _call} <- Calls.finish(call, :missed), do: :ok

      _answered_or_gone ->
        :ok
    end
  end
end
