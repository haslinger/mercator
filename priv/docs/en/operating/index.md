---
title: Operating
order: 0
---
Mercator runs as a Docker image (a Mix release) next to PostgreSQL, started with `docker compose`; each installation is one shop. Installing it on a server is described in `DOCKER.md` in the repository (prerequisites, reverse proxy, first start). These chapters are for running it:

- [Configuration](configuration.md): the settings in `.env`.
- [Maintenance](maintenance.md): updates, logs, console, backups.
- [Demo mode](demo.md): the public demo with its nightly reset.
- [Troubleshooting](troubleshooting.md).

Problems the shop notices itself (emails that could not be sent, PDFs that failed, payment problems) appear under **Administration → Incidents**.
