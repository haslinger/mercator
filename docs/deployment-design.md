# Deployment and demo mode (phase 8) – design

Draft of 2026-10-15. Decisions so far: #24 Docker; #44–#48 demo mode (below); #114 an
existing reverse proxy on the home server does HTTPS; #115 emails are really sent by
SMTP; #116 the image is built on the server from a git checkout; #117 the server is
x86_64 with Ubuntu 24.04 and Docker Compose v2 (like pan's QA server, whose setup this
follows).

## 1. Goals

- The demo runs at **https://biber.mittenin.at** on the home server, reachable from the
  internet, so payment webhooks (Mollie, phase 7) can be tested.
- One image for every deployment: demo or customer is a runtime switch
  (`MERCATOR_MODE=demo`, #48), no separate build.
- Setup, update and reset are a few documented commands (`DOCKER.md`).

## 2. Image (`Dockerfile`)

Two stages, like pan:

- **Build:** `hexpm/elixir:1.20.4-erlang-29.1.1-ubuntu-noble-…` (the versions of
  `.tool-versions`), `MIX_ENV=prod`, deps, `mix assets.deploy` (Tailwind and esbuild come
  as Mix tools; no Node/npm needed), `mix release`.
- **Run:** `ubuntu:24.04` with the release, **Typst 0.15.1** (the official Linux binary,
  #104), fonts for the PDFs (Noto Sans, DejaVu Sans), `tzdata`, `ca-certificates`.
  Image processing (`image`/libvips) ships its own precompiled library.
- The demo photos (`assets/img`, ~100 MB) are copied into the image for seeding.
- An entrypoint runs the migrations, then starts the release.

## 3. Compose (`docker-compose.yml`)

- `app`: the image; publishes one HTTP port (default `4010`) for the reverse proxy.
- `db`: `postgres:17` with a health check; the app waits for it.
- Volumes: `db_data`, `uploads` (media library and product images).
- Everything secret or site-specific comes from `.env` (gitignored; `.env.example`
  documents it): `POSTGRES_PASSWORD`, `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET`,
  `PHX_HOST`, `TRUSTED_PROXIES` (the reverse proxy, for client IPs and rate limits),
  `MAIL_FROM_ADDRESS`, the SMTP settings, `MERCATOR_MODE`, `DEMO_ADMIN_PASSWORD`, and
  later `MOLLIE_API_KEY`.

The reverse proxy (#114) forwards `biber.mittenin.at` to the published port, with the
headers `X-Forwarded-For`/`-Proto` and WebSocket upgrade for LiveView; `DOCKER.md` shows
an nginx example.

## 4. Email (#115)

Swoosh's SMTP adapter with the `gen_smtp` library (#119): `SMTP_RELAY`, `SMTP_PORT`
(465 with TLS, the default, or 587 with STARTTLS), `SMTP_USERNAME`, `SMTP_PASSWORD`;
the server certificate is verified unless `SMTP_TLS_VERIFY=false`. Without
`SMTP_RELAY` the release refuses to start (no silently lost emails). Undeliverable
emails become incidents (failed Oban jobs, #105).

## 5. Demo mode (#44–#48)

`Mercator.Demo.enabled?()` (`MERCATOR_MODE=demo`) bundles all demo behaviour:

- **Seeding:** at start, if the database has no users, the demo data is seeded
  (`Mercator.Release.seed/0`): catalogue with photos, pages, orders, conversations,
  offers. The admin gets `DEMO_ADMIN_PASSWORD` (#45); all other demo accounts the public
  password `mercator-demo` (#47).
- **Login page:** lists the public demo logins (sales, sales manager, content, products,
  customers) and says that everything is reset every night.
- **Protection (#46):** the public demo accounts cannot change password, email or roles
  and cannot request a password reset.
- **Badge:** a small "Demo" badge in the header and the admin area.
- **Payment:** the payment simulator is registered and active (no real payment); Mollie
  in test mode can be switched on once its key is set.
- **Nightly reset:** an Oban cron job (03:00 Vienna time) empties all tables (except the
  migrations), removes uploads and seeds again. Accounts visitors registered are gone
  too.

## 6. Steps (one commit each, with tests)

1. Release: `Mercator.Release` (migrate, seed), `Dockerfile`, `.dockerignore`,
   `docker-compose.yml`, `.env.example`, `DOCKER.md`; SMTP in `runtime.exs`; build and run
   the image locally.
2. ~~Demo mode~~ *(done 2026-10-15)*: `Mercator.Demo`, seeding at start (a task
   in the supervision tree), login page (`MercatorWeb.SignInLive` with
   `MercatorWeb.DemoComponents`), protection (validation/preparation
   `NotPublicDemoAccount`), badge, simulator registered by runtime.exs and
   activated by seeding, nightly reset (`Mercator.Demo.Workers.Reset`; Oban cron
   now runs in the shop's time zone).
3. On the home server: checkout, `.env`, reverse proxy entry, `docker compose up -d`
   (done by you, with `DOCKER.md`); smoke test.
4. Phase 7 step 3: Mollie with webhooks against the real domain.

## 7. Answered questions

- **#118** (2026-10-15) Emails are sent by the mittenin.at mail server
  (`box.mittenin.at`, port 465 with TLS), like pan.
- **#119** (2026-10-15) `gen_smtp` added as a dependency for Swoosh's SMTP adapter.
