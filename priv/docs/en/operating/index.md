---
title: Operating
order: 0
---
Mercator runs as a Docker image (a Mix release) with PostgreSQL, started with `docker compose`. Each installation is one shop (one customer per installation).

- **Configuration:** everything secret or site-specific is in the `.env` file next to `docker-compose.yml`.
- **Updating:** `git pull && docker compose build && docker compose up -d`. The database and uploads stay; migrations run at startup.
- **Problems** the shop notices itself appear under Administration → Incidents.
