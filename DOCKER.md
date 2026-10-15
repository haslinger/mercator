# 🐳 Mercator in Docker

How to run Mercator on a server with Docker: the Biber Holz demo at
`https://biber.mittenin.at`, or a customer's shop. Design and decisions:
[docs/deployment-design.md](docs/deployment-design.md).

## 📋 Prerequisites

* A server with Ubuntu 24.04 on x86_64 (the `Dockerfile`'s base images are pinned
  to match; see Troubleshooting if it differs)
* Docker and Docker Compose v2
* This repository checked out on the server
* Your user in the `docker` group (`sudo usermod -aG docker $USER`, then log
  out and in), otherwise prefix the commands below with `sudo`
* A reverse proxy on the server that does HTTPS for the domain (see below)
* A DNS record for the domain pointing to the server, and ports 80/443 reaching
  the reverse proxy

## 🧱 What runs

* `app`: the Mercator release. Before every start it runs the database
  migrations. It contains Typst and fonts for the PDF documents, and the demo
  photos for seeding.
* `db`: PostgreSQL 17.
* Volumes: `db_data` (the database) and `uploads` (product images, media
  library, chat files). Both survive `down`/`up`; `down -v` deletes them.

The app is published on `127.0.0.1:4010` only: the reverse proxy on the same
host is the only way in.

## 🛠 Setup

```sh
cp .env.example .env
$EDITOR .env
```

In `.env` set at least:

* `POSTGRES_PASSWORD`: any strong password; used by both services.
* `SECRET_KEY_BASE` and `TOKEN_SIGNING_SECRET`: two different values of
  ```sh
  openssl rand -base64 48
  ```
* `PHX_HOST`: the public domain, e.g. `biber.mittenin.at` (used for links in
  emails, PDFs and payment pages).
* The SMTP settings: `SMTP_RELAY`, `SMTP_PORT` (465 with TLS, or 587 with
  STARTTLS), `SMTP_USERNAME`, `SMTP_PASSWORD`, and `MAIL_FROM_ADDRESS`, an
  address the SMTP account may send as. Without `SMTP_RELAY` the app does not
  start, so emails are never lost silently.
* `BRAND`: one of the brands in `config/brands/`, e.g. `biberholz` (name,
  logo, colours, contact data); empty for the neutral Mercator look.
* For the demo: `MERCATOR_MODE=demo` and `DEMO_ADMIN_PASSWORD` (the
  administrator's password, never published; at least 8 characters, and
  not `change-me`). For a customer's shop leave `MERCATOR_MODE` empty.

`.env` is gitignored, so `git pull` never touches it. It is read when the
containers start; after changing it, `docker compose up -d` is enough.

## 🔀 Reverse proxy

The proxy terminates HTTPS and forwards to `http://127.0.0.1:4010`. LiveView
needs WebSockets, and the app needs the original host, scheme and client
address. An nginx example:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name biber.mittenin.at;
    # ssl_certificate … (e.g. from certbot)

    client_max_body_size 50m;   # uploads (product images, media, chat files)

    location / {
        proxy_pass http://127.0.0.1:4010;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }
}
```

The same with Caddy (`Caddyfile`). Caddy gets the certificate by itself and
already forwards WebSockets, the host and `X-Forwarded-For`/`-Proto`, and it
speaks HTTP/1.1 to the app:

```caddy
biber.mittenin.at {
    request_body {
        max_size 50MB   # uploads (product images, media, chat files)
    }
    reverse_proxy 127.0.0.1:4010
}
```

After changing it: `sudo systemctl reload caddy` (or `caddy reload` in the
directory of the `Caddyfile`).

If your reverse proxy runs in a container itself (e.g. Nginx Proxy Manager, a Caddy container,
Traefik), `127.0.0.1` is not reachable from it: change the port mapping in
`docker-compose.yml` to the host's Docker address or put both on one Docker
network.

The app believes `X-Forwarded-For` only from `TRUSTED_PROXIES` (default:
Docker's networks `172.16.0.0/12`). The proxy should speak HTTP/1.1 to the app
(as above): Bandit, the app's web server, has an open HTTP/2 issue that only
matters when it serves HTTP/2 itself.

## 🏗 Build and run

```sh
docker compose build
docker compose up -d
```

The first build takes a few minutes (dependencies, assets, release). The
database starts empty and is migrated automatically.

### Demo data

With `MERCATOR_MODE=demo` the app seeds itself when it starts with an empty
database (watch `docker compose logs -f app`; the photos take a minute): the
Biber Holz catalogue with photos, pages, orders, conversations and offers,
and the demo users. The administrator `admin@mittenin.at` gets
`DEMO_ADMIN_PASSWORD` (the app does not start without it); all other demo
users have the password `mercator-demo`. The sign-in page offers them as
one-click "Anmelden" buttons, without showing their addresses or the password
(so spam bots cannot harvest them). They cannot change their password or
roles or reset their password.
The payment simulator is the active payment provider.

Every night at 03:00 (shop time) the demo is reset: all tables are emptied
(accounts visitors registered included), uploads are deleted and the demo
data is seeded again. To reset by hand:

```sh
docker compose exec app bin/mercator rpc "Mercator.Demo.reset()"
```

To seed again without emptying (idempotent):
`docker compose exec app bin/mercator rpc "Mercator.Release.seed()"`
(`rpc` runs it inside the running app; `eval` would start a second one).

## 🔍 Verify

```sh
docker compose ps
docker compose logs -f app
```

Then open `https://<your domain>`. Check an email (e.g. "forgot password") and
a PDF (an offer's "Download PDF") once: both need the outside world (SMTP) and
Typst in the image.

## 🖥 Remote console

```sh
docker compose exec app bin/mercator remote
```

## 🔄 Update after a code change

```sh
git pull
docker compose build
docker compose up -d
```

Migrations run on start. Uploads and the database stay.

## 🧹 Reset to a clean slate

Deletes the database and all uploads:

```sh
docker compose down -v
docker compose up -d
```

## 💾 Backup

```sh
docker compose exec db pg_dump -U postgres mercator | gzip > mercator-$(date +%F).sql.gz
docker compose run --rm --no-deps --entrypoint tar -v "$PWD":/backup app \
  czf /backup/uploads-$(date +%F).tar.gz -C /data uploads
```

## 🔧 Troubleshooting

* `docker compose` refuses to start, saying a variable "is not set": `.env` is
  missing or incomplete, see Setup.
* The app restarts in a loop: `docker compose logs app` names the missing
  environment variable (e.g. `SMTP_RELAY`).
* `docker compose build` cannot pull the base image: look for a current tag on
  [hub.docker.com/r/hexpm/elixir/tags](https://hub.docker.com/r/hexpm/elixir/tags)
  and adjust `UBUNTU_TAG` in the `Dockerfile` (Elixir and Erlang as in
  `.tool-versions`). On another OS or CPU, also adjust `RUNNER_IMAGE` and the
  Typst download (e.g. `aarch64` on ARM).
* The page loads but stays "reconnecting": the proxy does not pass WebSocket
  upgrades (see the `Upgrade`/`Connection` headers above), or `PHX_HOST` does
  not match the domain.
* Emails do not arrive: failed emails become incidents in the admin area
  (Verwaltung → Vorfälle) with the SMTP error in the technical details.
