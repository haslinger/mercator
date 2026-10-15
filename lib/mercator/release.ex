defmodule Mercator.Release do
  @moduledoc """
  Tasks for the release, where Mix is not available (phase 8, see
  docs/deployment-design.md and DOCKER.md):

      bin/mercator eval "Mercator.Release.migrate()"
      bin/mercator rpc "Mercator.Release.seed()"   # inside the running app

  The Docker entrypoint runs `migrate/0` before every start.
  """
  alias Mercator.Demo

  @app :mercator

  @doc "Runs all pending migrations."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Rolls a repo back to a migration version."
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seeds the demo data (`Mercator.Demo.seed/0`). For the demo only (#44): a
  customer's shop starts empty. The demo seeds itself when it starts with an
  empty database, so this is only needed to seed again by hand.
  """
  def seed do
    {:ok, _apps} = Application.ensure_all_started(@app)
    users = Demo.seed()
    IO.puts("Seeded demo data: #{length(users)} demo users.")
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app, do: Application.load(@app)
end
