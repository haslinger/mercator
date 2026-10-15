---
title: Demo mode
order: 30
---
With `MERCATOR_MODE=demo` the installation is a public demo (like the Biber Holz demo). One switch turns on everything demo-specific:

- **Seeding:** on its first start with an empty database the app loads the demo data: catalogue with photos, pages, orders, conversations, offers and demo users (takes about a minute).
- **Demo users:** the administrator gets `DEMO_ADMIN_PASSWORD` and is never shown publicly. All other demo users have the password `mercator-demo`; the sign-in page offers them as one-click buttons without showing addresses or the password. They cannot change their password or roles or reset their password.
- **Payment:** the payment simulator is the active provider, so nobody pays real money.
- **Nightly reset at 03:00** (shop time): all tables are emptied (accounts visitors registered included), uploads deleted, and the demo data seeded again.
- **Making-of:** the session logs and project metrics at `/making-of`, linked in the footer.
- A **Demo** badge in the header.

## By hand

```sh
docker compose exec app bin/mercator rpc "Mercator.Demo.reset()"     # reset now
docker compose exec app bin/mercator rpc "Mercator.Release.seed()"   # seed again without emptying
```

If seeding stopped halfway at the first start, a restart does not seed again (users exist already); the reset command fixes that.

Changing `DEMO_ADMIN_PASSWORD` takes effect with the next reset, because the password is set when the account is created.
