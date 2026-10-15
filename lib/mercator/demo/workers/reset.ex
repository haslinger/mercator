defmodule Mercator.Demo.Workers.Reset do
  @moduledoc """
  Nightly at 03:00 shop time: resets the demo (`Mercator.Demo.reset/1`).
  Does nothing outside demo mode, so the cron entry can stay in every
  deployment's config.
  """
  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 3600]

  alias Mercator.Demo

  @impl Oban.Worker
  def perform(%Oban.Job{id: id}) do
    if Demo.enabled?(), do: Demo.reset(id), else: :ok
  end
end
