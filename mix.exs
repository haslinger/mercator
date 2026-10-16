defmodule Mercator.MixProject do
  use Mix.Project

  def project do
    [
      app: :mercator,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev,
      usage_rules: usage_rules()
    ]
  end

  # Usage rules for AI coding agents, synced with `mix usage_rules.sync`.
  # Elixir/OTP and Phoenix rules are inlined into AGENTS.md; the larger
  # Ash rules are built into an on-demand Claude Code skill.
  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: ["usage_rules:all", "phoenix:all"],
      skills: [
        location: ".claude/skills",
        build: [
          "ash-framework": [
            description:
              "Use this skill working with Ash Framework or any of its extensions. Always consult this when making any domain changes, features or fixes.",
            usage_rules: [:ash, ~r/^ash_/]
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Mercator.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ash_admin, "~> 1.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:image, "~> 0.72"},
      {:usage_rules, "~> 1.0", only: [:dev]},
      {:tidewave, "~> 0.9", only: [:dev]},
      {:picosat_elixir, "~> 0.2"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # security checks for Phoenix (XSS, SQL injection, configuration, …)
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:oban, "~> 2.0"},
      {:ash_paper_trail, "~> 0.8"},
      {:ash_state_machine, "~> 0.2"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:phoenix, "~> 1.8.15"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      # database page of the LiveDashboard (#134)
      {:ecto_psql_extras, "~> 0.8.8"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      # SMTP adapter of Swoosh (#115, #119)
      {:gen_smtp, "~> 1.3"},
      {:hammer, "~> 7.5"},
      {:mdex, "~> 0.14.2"},
      {:req, "~> 0.5"},
      {:tz, "~> 0.28.4"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind mercator", "esbuild mercator"],
      "assets.deploy": [
        "tailwind mercator --minify",
        "esbuild mercator --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "credo --strict",
        # security checks, see .sobelow-conf
        "sobelow --config",
        "test"
      ]
    ]
  end
end
