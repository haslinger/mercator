# Mercator

Mercator is a guided-selling web shop with a CMS. Customers can shop on their own or get help from a sales consultant (chat, offers, shared documents).

It is a port of the Rails/Hobo application of the same name to **Elixir, Phoenix 1.8, Ash 3, LiveView and DaisyUI 5** on PostgreSQL. Mercator is a generic product: each customer gets its own deployment (single tenant), customised through configuration, a DaisyUI theme and optional modules.

- Plan, decisions and open questions: [docs/roadmap.md](docs/roadmap.md)
- Conventions for development (including AI agents): [CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md)

## Requirements

- **Erlang/OTP and Elixir** in the versions pinned in [.tool-versions](.tool-versions). With asdf, run `asdf install` in the project directory.
- **PostgreSQL** (developed against version 18).
- A C compiler. `bcrypt_elixir` compiles a native extension.

## Getting started

```sh
mix setup          # fetch deps, create and migrate the database, build assets, run seeds
mix phx.server     # or: iex -S mix phx.server
```

Then open [localhost:4000](http://localhost:4000).

`mix setup` also loads demo data (`mix run priv/repo/seeds.exs`, safe to repeat), including the demo images from `assets/img/` (`mix run priv/repo/import_images.exs` imports them on their own; uploads are stored in `uploads/`). The demo users all have the password `mercator-demo`:

| Email | Name | Roles |
|---|---|---|
| `admin@example.com` | Anna Specht | administrator |
| `sales@example.com` | Sepp Fuchs | sales |
| `manager@example.com` | Maria Hirsch | sales, sales_manager |
| `content@example.com` | Klara Eichhorn | contentmanager |
| `products@example.com` | Peter Dachs | productmanager |
| `kunde@example.com` | Karl Luchs | customer (German) |
| `customer@example.com` | Lena Igel | customer (English) |

In development:

- emails are not sent; they appear in the mailbox preview at [localhost:4000/dev/mailbox](http://localhost:4000/dev/mailbox)
- the LiveDashboard is at [localhost:4000/dev/dashboard](http://localhost:4000/dev/dashboard)
- the [Tidewave](https://tidewave.ai) MCP server is at `localhost:4000/tidewave/mcp` (registered for Claude Code in `.mcp.json`)

## Branding

Every deployment has its own branding: shop name, tagline, contact data, images and DaisyUI themes. It is configured with `config :mercator, :brand, …` (see `Mercator.Brand` for all keys); unset keys fall back to the neutral Mercator defaults.

- Images live in `priv/static/images/brands/<brand>/`. Pages refer to them only through stable URLs (`/brand/logo`, `/brand/pin`, `/brand/favicon`, `/brand/apple-touch-icon`).
- Themes are defined in `assets/css/app.css`. The brand names one theme for light mode and one for dark mode.
- Development uses the demo brand **Biber Holz** (`config/dev.exs`); tests use the neutral default.

## Database

Development and test expect a local PostgreSQL with user `postgres`, password `postgres` and the databases `mercator_dev` and `mercator_test` (see `config/dev.exs` and `config/test.exs`).

```sh
mix ash.setup      # create and migrate
mix ash.reset      # drop, recreate and migrate
mix ash.codegen <name>   # generate migrations after changing Ash resources
```

### Note: server messages must be in English

The repo connection sets the Postgres parameter `lc_messages=C`, in `config/config.exs`. AshPostgres only recognises the errors it raises inside the database (e.g. for authorization checks in atomic updates) when Postgres reports them with the English severity `ERROR`. A server with a localised `lc_messages` (e.g. German, `FEHLER`) would turn "forbidden" into "unknown error".

Setting `lc_messages` on a connection requires a **superuser** or an explicit grant:

```sql
GRANT SET ON PARAMETER lc_messages TO mercator;   -- PostgreSQL 15+
```

If that isn't possible (e.g. on managed databases), remove the `parameters:` option from the repo config, and configure English messages on the server or database instead:

```sql
ALTER DATABASE mercator SET lc_messages = 'C';   -- also requires a superuser
```

## Quality checks

```sh
mix precommit      # compile with warnings as errors, unlock unused deps, format, credo --strict, tests
mix test
```

## Production configuration

Production is configured through environment variables, read in `config/runtime.exs`:

| Variable | Required | Purpose |
|---|---|---|
| `DATABASE_URL` | yes | e.g. `ecto://USER:PASS@HOST/DATABASE` |
| `SECRET_KEY_BASE` | yes | Signs and encrypts cookies; generate with `mix phx.gen.secret` |
| `TOKEN_SIGNING_SECRET` | yes | Signs authentication tokens; generate with `mix phx.gen.secret` |
| `PHX_HOST` | yes | Public host name, used for generated URLs (e.g. in emails) |
| `MAIL_FROM_ADDRESS` | yes | Sender address of all system emails |
| `UPLOADS_DIR` | yes | Directory for uploaded files (product and category images); must be persistent and writable |
| `MAIL_FROM_NAME` | no | Sender name (default `Mercator`) |
| `PORT` | no | HTTP port (default `4000`) |
| `POOL_SIZE` | no | Database connection pool size (default `10`) |
| `ECTO_IPV6` | no | Set to `true` to connect to the database over IPv6 |
| `PHX_SERVER` | no | Set to `true` to start the web server when running a release |
| `DNS_CLUSTER_QUERY` | no | DNS query for clustering several nodes |
| `SHOP_TIME_ZONE` | no | Time zone for displayed times and "today" (default `Europe/Vienna`) |
| `TRUSTED_PROXIES` | no | Comma-separated IPs of reverse proxies whose `X-Forwarded-For` header is believed (default `127.0.0.1,::1`) |

### Reverse proxy and rate limiting

The app limits what it can tell apart itself (`Mercator.RateLimit`, limits in `config/config.exs`): sign-ins per email address, password reset and magic link emails per address, and contact form messages per client IP. Everything that is about the volume of traffic from one IP address belongs at the reverse proxy (e.g. nginx). Recommended there (details to be worked out per deployment):

- **A general request rate per client IP** for all routes, with some burst, against floods and scrapers.
- **A stricter rate per client IP for the authentication pages and endpoints:** `/sign-in`, `/register`, `/reset`, `/auth/…` and `/sign-out`. Registration in particular is only limited here.
- **A limit on new LiveView connections per client IP** (`/live/websocket`, `/live/longpoll`): sign-in, registration and the contact form send their data through the LiveView connection, so the proxy sees connections rather than individual attempts.
- **A limit on concurrent connections per client IP.**
- **A request body size** that allows uploads (images and PDFs up to 20 MB each) but not more.
- The proxy must set `X-Forwarded-For` (and pass WebSocket upgrades); add its address to `TRUSTED_PROXIES` so the app sees the visitor's IP.

Still open for production:

- **Email delivery:** a Swoosh adapter for production is not configured yet; see the example in `config/runtime.exs`.
- **Deployment target:** open question #24 in the roadmap.
- **Postgres:** see the note above on `lc_messages`.

## License

Mercator is free software: you can redistribute it and/or modify it under the terms of the **GNU General Public License** as published by the Free Software Foundation, either **version 3** of the License, or (at your option) **any later version** (SPDX: `GPL-3.0-or-later`). See [LICENSE](LICENSE).
