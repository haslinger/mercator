defmodule Mercator.Operations.JobFailures do
  @moduledoc """
  Turns background jobs that failed for good (all attempts used, or
  discarded) into incidents (#105), so a confirmation email that could not
  be sent does not vanish in the log. Attached at application start.

  Incidents link to the order, offer or conversation named in the job's
  arguments.
  """
  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Operations.Incidents

  @handler "mercator-job-failures"
  @links ~w(order_id offer_id conversation_id)

  @doc "Attaches the telemetry handler for `[:oban, :job, :exception]`."
  def attach do
    :telemetry.attach(@handler, [:oban, :job, :exception], &__MODULE__.handle_event/4, nil)
  end

  @doc false
  def handle_event([:oban, :job, :exception], _measurements, %{state: :discard} = meta, _config),
    do: report(meta)

  def handle_event(_event, _measurements, _meta, _config), do: :ok

  @doc "Reports the failed job of the telemetry metadata as an incident."
  def report(%{job: job} = meta) do
    worker = job.worker |> String.split(".") |> List.last()

    Incidents.in_shop_locale(fn ->
      %{
        kind: :job,
        title: gettext("Background job %{worker} failed", worker: worker),
        description:
          gettext(
            "A background job failed %{count} times and was given up. What it should have done (e.g. send an email) has not happened.",
            count: job.attempt
          ),
        details: details(job, meta),
        fingerprint: "job|#{job.worker}|#{Jason.encode!(job.args)}"
      }
      |> Map.merge(links(job.args))
      |> Incidents.report()
    end)

    :ok
  end

  defp details(job, meta) do
    error =
      case meta do
        %{kind: kind, reason: reason, stacktrace: stacktrace} when is_list(stacktrace) ->
          Exception.format(kind, reason, stacktrace)

        %{reason: reason} ->
          inspect(reason)

        _meta ->
          "unknown error"
      end

    "Job #{job.id}, args #{Jason.encode!(job.args)}\n\n#{error}"
  end

  defp links(args) do
    for key <- @links, value = args[key], is_binary(value), into: %{} do
      {String.to_existing_atom(key), value}
    end
  end
end
