# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mercator, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  lifeline: [rescue_after: {2, :hours}],
  pruner: [max_age: {1, :day}],
  # times in the shop's time zone (:time_zone; SHOP_TIME_ZONE sets both)
  timezone: "Europe/Vienna",
  crontab: [
    {"30 2 * * *", Mercator.Sales.Workers.DeleteAbandonedBaskets},
    {"5 0 * * *", Mercator.Consulting.Workers.ExpireOffers},
    # only does something in demo mode (Mercator.Demo)
    {"0 3 * * *", Mercator.Demo.Workers.Reset}
  ],
  repo: Mercator.Repo

# These enable behaviors that will become the default in the next major
# version of Ash. Setting them now opts your application into the new
# behavior and ensures a seamless upgrade. See the backwards compatibility
# guide for an explanation of each setting:
# https://hexdocs.pm/ash/backwards-compatibility-config.html
config :ash,
  allow_forbidden_field_for_relationships_by_default: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  default_string_length_count: :codepoints,
  infer_generic_action_reactors?: false,
  many_to_many_destroy_destination_on_match?: true,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :admin,
        :authentication,
        :token,
        :user_identity,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [:admin, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

# AshPostgres recognises its own database errors only when Postgres reports
# them with the English severity "ERROR". Localised servers (e.g. German
# "FEHLER") would turn policy errors into unknown errors, so force English
# server messages. Setting lc_messages needs superuser rights or a matching
# GRANT SET; alternatively configure lc_messages on the database server.
config :mercator, Mercator.Repo, parameters: [lc_messages: "C"]

config :mercator,
  ecto_repos: [Mercator.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    Mercator.Accounts,
    Mercator.Catalog,
    Mercator.Sales,
    Mercator.Content,
    Mercator.Consulting,
    Mercator.Operations
  ],
  ash_authentication: [return_error_on_invalid_magic_link_token?: true]

# Configure the endpoint
config :mercator, MercatorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MercatorWeb.ErrorHTML, json: MercatorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mercator.PubSub,
  live_view: [signing_salt: "HparGl88"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :mercator, Mercator.Mailer, adapter: Swoosh.Adapters.Local

# UI languages; German is the default
config :mercator, MercatorWeb.Gettext, default_locale: "de", locales: ~w(de en)

# Languages of translatable content (Mercator.Translated); the first is the
# default and fallback. Keep in sync with the UI languages above.
config :mercator, :content_locales, ~w(de en)

# Time zone of the shop (#73): times are stored in UTC and shown in this zone;
# "today" (price validity, order number year, date filters) follows it too.
# Override with SHOP_TIME_ZONE at runtime.
config :elixir, :time_zone_database, Tz.TimeZoneDatabase
config :mercator, :time_zone, "Europe/Vienna"

# Rate limits (#87) as {count, period in ms}: sign-ins per email address,
# password reset / magic link emails per address, contact form messages per
# client IP. See Mercator.RateLimit.
config :mercator, :rate_limits,
  sign_in: {10, :timer.minutes(15)},
  auth_email: {3, :timer.minutes(15)},
  contact: {5, :timer.hours(1)}

# Guided selling (#95): seconds a customer waits for a consultant before the
# callback form appears (immediately when nobody is at the sales desk)
config :mercator, :consulting_wait_seconds, 120

# AutoCAD drawings may be shared in conversations (Mercator.Content.FileTypes);
# the mime package does not know them (needs `mix deps.compile mime --force`)
config :mime, :types, %{
  "image/vnd.dwg" => ["dwg"],
  "image/vnd.dxf" => ["dxf"]
}

# Offers: default validity in days, and the discount in percent above which
# a sales manager approves an offer (#98)
config :mercator, :offer_validity_days, 30
config :mercator, :offer_approval_limit, 10

# Reverse proxies whose X-Forwarded-For header is believed (MercatorWeb.ClientIp);
# override with TRUSTED_PROXIES (comma-separated) at runtime.
config :mercator, :trusted_proxies, ["127.0.0.1", "::1"]

# Countries the shop delivers to (#67); billing addresses may be in any EU country
config :mercator, :delivery_countries, ~w(AT DE IT)

# Shipping methods in display order with their costs (#65): gross amounts in EUR
# per country zone, plus an optional percentage of the goods value (#112), and
# optionally free from an order value (goods, gross). See Mercator.Sales.Shipping.
config :mercator, :shipping,
  parcel: [
    rates: [
      %{countries: ~w(AT), gross: "9.90", free_from: "250"},
      %{countries: ~w(DE IT), gross: "14.90", free_from: "500"}
    ]
  ],
  freight: [
    rates: [
      %{countries: ~w(AT), gross: "89", percent: "2"},
      %{countries: ~w(DE IT), gross: "189", percent: "3"}
    ]
  ],
  pickup: []

# Payment methods offered at checkout (#64); see Mercator.Sales.Payment
config :mercator, :payment_methods, [:online, :prepayment, :invoice, :on_pickup]

# Online payment providers of the deployment (phase 7); administrators switch
# between them. :online is only offered while one is active. The simulator is
# never registered here (customers could "pay" without paying): only in dev,
# test and the demo. See Mercator.Payments.
config :mercator, :payment_providers, []

# Sender of all system emails; override per deployment in runtime.exs
config :mercator, :mail_from, {"Mercator", "noreply@localhost"}

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mercator: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  mercator: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Brands (#36, #43); the active one is chosen by `:brand_key` (BRAND in production)
import_config "brands/biberholz.exs"

import_config "#{config_env()}.exs"
