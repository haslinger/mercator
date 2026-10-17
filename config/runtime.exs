import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/mercator start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :mercator, MercatorWeb.Endpoint, server: true
end

config :mercator, MercatorWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# one of the brands of config/brands/ (#43), e.g. BRAND=biberholz
if brand = System.get_env("BRAND") do
  brands = Application.get_env(:mercator, :brands, [])

  key =
    Enum.find(Keyword.keys(brands), &(to_string(&1) == brand)) ||
      raise "unknown BRAND #{inspect(brand)}; known: #{Enum.join(Keyword.keys(brands), ", ")}"

  config :mercator, :brand_key, key
end

# guided selling (#95): seconds a customer waits for a consultant before the
# callback form appears, e.g. CONSULTING_WAIT_SECONDS=300 (default 180)
with seconds when seconds not in [nil, ""] <- System.get_env("CONSULTING_WAIT_SECONDS") do
  case Integer.parse(seconds) do
    {seconds, ""} when seconds > 0 -> config :mercator, :consulting_wait_seconds, seconds
    _ -> raise "CONSULTING_WAIT_SECONDS must be a number of seconds, got #{inspect(seconds)}"
  end
end

if time_zone = System.get_env("SHOP_TIME_ZONE") do
  config :mercator, :time_zone, time_zone
  config :mercator, Oban, timezone: time_zone
end

# video advice (phase 10, docs/video-design.md section 6): the UDP ports for
# media, e.g. CALL_PORT_RANGE=50000-50049 (published by Docker with the same
# numbers), the server's public host name, e.g. CALL_PUBLIC_HOST=shop.example.org
# (needed inside a container), and STUN servers, e.g.
# CALL_ICE_SERVERS=stun:stun.example.org:3478 (comma-separated); all optional
calls =
  [
    ice_port_range:
      with range when range not in [nil, ""] <- System.get_env("CALL_PORT_RANGE") do
        case Regex.run(~r/^(\d+)-(\d+)$/, range) do
          [_, first, last] -> String.to_integer(first)..String.to_integer(last)
          nil -> raise "CALL_PORT_RANGE must look like 50000-50049, got #{inspect(range)}"
        end
      end,
    public_host:
      with host when host not in [nil, ""] <- System.get_env("CALL_PUBLIC_HOST") do
        host
      end,
    ice_servers:
      with servers when is_binary(servers) <- System.get_env("CALL_ICE_SERVERS") do
        for url <- String.split(servers, ",", trim: true), do: %{urls: String.trim(url)}
      end
  ]
  |> Enum.reject(fn {_key, value} -> value in [nil, "", []] end)

if calls != [], do: config(:mercator, Mercator.Consulting.Calls, calls)

# Mollie (phase 7): test_… only simulates payments, live_… takes real money
if config_env() != :test do
  if api_key = System.get_env("MOLLIE_API_KEY") do
    config :mercator, Mercator.Payments.Mollie, api_key: api_key
  end
end

# Web Push (#151, Mercator.WebPush): the shop's key pair, from
# `mix mercator.gen.vapid`; without it there are no phone notifications
if config_env() == :prod do
  with public when public not in [nil, ""] <- System.get_env("VAPID_PUBLIC_KEY"),
       private when private not in [nil, ""] <- System.get_env("VAPID_PRIVATE_KEY") do
    config :mercator, Mercator.WebPush,
      public_key: public,
      private_key: private,
      subject: System.get_env("VAPID_SUBJECT")
  end
end

# Demo mode (#48, Mercator.Demo): MERCATOR_MODE=demo, empty for a real shop
case System.get_env("MERCATOR_MODE", "") do
  "" ->
    :ok

  "demo" ->
    config :mercator, :demo_mode, true

    # no real payment in the demo: the simulator is registered (and activated by seeding)
    providers = Application.get_env(:mercator, :payment_providers, [])
    config :mercator, :payment_providers, Enum.uniq([Mercator.Payments.Simulator | providers])

    if config_env() == :prod do
      # the administrator's password is never published (#45)
      password = System.get_env("DEMO_ADMIN_PASSWORD", "")

      if String.length(password) < 8 or password == "change-me",
        do: raise("DEMO_ADMIN_PASSWORD must be set (at least 8 characters, not change-me).")

      config :mercator, :demo_admin_password, password
    end

  other ->
    raise "unknown MERCATOR_MODE #{inspect(other)}; use demo or leave it empty"
end

if proxies = System.get_env("TRUSTED_PROXIES") do
  config :mercator,
         :trusted_proxies,
         proxies |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :mercator, MercatorWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/mercator_web/router\.ex$"E,
        ~r"lib/mercator_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  config :mercator,
         :uploads_dir,
         System.get_env("UPLOADS_DIR") ||
           raise("environment variable UPLOADS_DIR is missing (directory for uploaded files).")

  config :mercator,
         :mail_from,
         {System.get_env("MAIL_FROM_NAME", "Mercator"),
          System.get_env("MAIL_FROM_ADDRESS") ||
            raise("environment variable MAIL_FROM_ADDRESS is missing.")}

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :mercator, Mercator.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "biber.mittenin.at"

  config :mercator, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :mercator, MercatorWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  config :mercator,
    token_signing_secret:
      System.get_env("TOKEN_SIGNING_SECRET") ||
        raise("Missing environment variable `TOKEN_SIGNING_SECRET`!")

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :mercator, MercatorWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :mercator, MercatorWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # Emails by SMTP (#115), e.g. box.mittenin.at on port 465 with TLS. Without
  # SMTP_RELAY the release does not start: no silently lost emails.
  config :mercator, Mercator.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("SMTP_RELAY") || raise("environment variable SMTP_RELAY is missing."),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    port: String.to_integer(System.get_env("SMTP_PORT", "465")),
    # 465: TLS from the start; 587: STARTTLS (set SMTP_PORT=587)
    ssl: System.get_env("SMTP_PORT", "465") == "465",
    tls: if(System.get_env("SMTP_PORT", "465") == "465", do: :never, else: :always),
    auth: if(System.get_env("SMTP_USERNAME"), do: :always, else: :never),
    # the server certificate is checked unless SMTP_TLS_VERIFY=false
    sockopts:
      if(System.get_env("SMTP_TLS_VERIFY") == "false",
        do: [verify: :verify_none],
        else: [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          # gen_smtp defaults to depth 0 (no intermediate certificate), which
          # rejects e.g. every Let's Encrypt chain (:max_path_length_reached)
          depth: 10,
          server_name_indication: String.to_charlist(System.get_env("SMTP_RELAY")),
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
      ),
    retries: 1,
    no_mx_lookups: true

  # demo photos for seeding (the Docker image has them in /app/demo-img)
  if dir = System.get_env("DEMO_IMAGE_DIR") do
    config :mercator, :demo_image_dir, dir
    config :mercator, :seed_image_dir, Path.join(dir, "categories")
  end
end
