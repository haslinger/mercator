import Config
config :mercator, Oban, testing: :manual
# Uploaded files in tests; each test run starts empty (see test_helper.exs)
config :mercator, :uploads_dir, Path.expand("../tmp/test_uploads", __DIR__)

config :mercator, token_signing_secret: "ilfoFdFrYuSbZKTWiq0aRYjeMPbEUawB"
config :bcrypt_elixir, log_rounds: 1

# Shipping in tests: freight as estimates ("from", confirmed by staff), so that
# mode stays covered; calculated costs (#112) are tested in ShippingTest
config :mercator, :shipping,
  parcel: [
    rates: [
      %{countries: ~w(AT), gross: "9.90", free_from: "250"},
      %{countries: ~w(DE IT), gross: "14.90", free_from: "500"}
    ]
  ],
  freight: [
    estimate: true,
    rates: [%{countries: ~w(AT), gross: "89"}, %{countries: ~w(DE IT), gross: "189"}]
  ],
  pickup: []

config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mercator, Mercator.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mercator_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mercator, MercatorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BwGIHwxWuVhqh55jR4ulf+1WynJSRJuMDYk+TOaOTi1ZKMqu1cSynUcakxQQFknl",
  server: false

# In test we don't send emails
config :mercator, Mercator.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# demo pages without photos in tests (Mercator.Seeds.Pages), much faster
config :mercator, :seed_image_dir, nil

# Online payment: the simulator (no real payment), see Mercator.Payments
config :mercator, :payment_providers, [Mercator.Payments.Simulator]

# The Mollie adapter is tested against stubbed responses (Mercator.Payments.MollieTest)
config :mercator, Mercator.Payments.Mollie,
  api_key: "test_dummy",
  req_options: [plug: {Req.Test, Mercator.Payments.Mollie}]
