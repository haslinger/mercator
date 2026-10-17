---
title: Configuration
order: 10
---
Everything secret or specific to the installation is in the file `.env` next to `docker-compose.yml`; nothing of it is in the image or the repository. After a change, `docker compose up -d` is enough: Compose recreates the app container, no build needed.

| Variable | Meaning |
|---|---|
| `POSTGRES_PASSWORD` | database password, used by both containers |
| `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET` | two different secrets, each from `openssl rand -base64 48` |
| `PHX_HOST` | the public domain, e.g. `shop.example.com`; used for links in emails, PDFs and payment pages |
| `APP_PORT` | port on `127.0.0.1` the reverse proxy forwards to (default 4010) |
| `TRUSTED_PROXIES` | addresses or networks of the reverse proxy whose `X-Forwarded-For` is believed (default Docker's `172.16.0.0/12`); needed for the client IP in rate limits |
| `SMTP_RELAY`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | the mail server; port 465 (TLS) or 587 (STARTTLS). Without `SMTP_RELAY` the app does not start |
| `SMTP_TLS_VERIFY` | `false` only if the mail server's certificate cannot be verified |
| `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | the sender of all emails; an address the SMTP account may send as |
| `BRAND` | the brand (name, logo, colours, contact data) from `config/brands/`, e.g. `biberholz`; empty for the neutral Mercator look |
| `SHOP_TIME_ZONE` | the shop's time zone (default `Europe/Vienna`): times on pages and in emails, "today" for price validity, the nightly jobs |
| `MOLLIE_API_KEY` | Mollie for online payment: `test_…` simulates payments, `live_…` takes real money. Then switch it on under Administration → Payment providers |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` | phone notifications (Web Push): the shop's key pair, generated with `mix mercator.gen.vapid`; free, no account needed. Without them there are no notifications. A new pair means everyone switches them on again at the desk |
| `VAPID_SUBJECT` | optional: a contact for the push services, e.g. `mailto:shop@example.com` (default: `MAIL_FROM_ADDRESS`) |
| `MERCATOR_MODE` | `demo` for the public demo, empty for a real shop (see [Demo mode](demo.md)) |
| `DEMO_ADMIN_PASSWORD` | demo only: the administrator's password, at least 8 characters |
| `CONSULTING_WAIT_SECONDS` | advice: seconds a customer waits for a consultant before the callback is offered (default `180`) |
| `CALL_PUBLIC_HOST` | video calls: the public host name (or IP) browsers reach the call media at, usually as `PHX_HOST`; without it calls only work inside the local network (see [Video calls](calls.md)) |
| `CALL_PORT_RANGE` | video calls: the UDP ports for the media (default `50000-50049`), published with the same numbers |
| `CALL_ICE_SERVERS` | video calls: optional STUN servers, comma-separated, e.g. `stun:stun.example.org:3478` |
| `MERCATOR_SUBNET`, `APP_IP` | the app's Docker network and fixed address (default `172.30.0.0/24`, `172.30.0.10`); change both if the network collides with another one on the host |

## Settings in the back office

Some settings are not in `.env` but in the admin area, for administrators: the active payment provider, users and their roles, tax classes. Shipping costs, payment methods and delivery countries are part of the shop's configuration in the code (`config/config.exs` and the brand), changed with a new release.
