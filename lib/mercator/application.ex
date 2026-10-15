defmodule Mercator.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Mercator.Operations.JobFailures

  @impl true
  def start(_type, _args) do
    # background jobs that fail for good become incidents (#105)
    JobFailures.attach()

    children = [
      MercatorWeb.Telemetry,
      Mercator.Repo,
      {DNSCluster, query: Application.get_env(:mercator, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:mercator, Oban)},
      {Phoenix.PubSub, name: Mercator.PubSub},
      MercatorWeb.Presence,
      {Mercator.RateLimit, clean_period: :timer.minutes(10)},
      # in-memory payments of the payment simulator (dev, tests, demo)
      Mercator.Payments.Simulator,
      # Start a worker by calling: Mercator.Worker.start_link(arg)
      # {Mercator.Worker, arg},
      # Start to serve requests, typically the last entry
      MercatorWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :mercator]}
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mercator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MercatorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
