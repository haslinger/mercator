---
title: Maintenance
order: 20
---
All commands run in the directory with `docker-compose.yml`.

## Updating

```sh
docker compose exec db pg_dump -U postgres mercator | gzip > mercator-$(date +%F).sql.gz
docker tag mercator:latest mercator:previous   # keep the running version for a rollback
git pull
docker compose build
docker compose up -d
docker image prune -f                          # delete untagged old images
```

The new app container runs the database migrations before it starts. The database and the uploads stay. Do **not** use `docker compose down -v` for an update: `-v` deletes the volumes, i.e. the database and all uploads.

Back up first: migrations change the database and are not undone. Every build tags the new image `mercator:latest`; the one before loses its tag and stays on disk until `docker image prune` deletes it. `mercator:previous` is a tag, so it is kept: there is always one version to go back to. On the very first update `docker tag` fails because there is no `mercator:latest` yet; that is fine.

## Rollback

```sh
docker tag mercator:previous mercator:latest
docker compose up -d --no-build
```

If the update ran migrations, the old version may not work with the new database: also restore the backup made before the update (see Backup). Before the next build, check out the old commit again, since `git pull` moved the checkout on.

## Disk space

```sh
docker system df                               # images, build cache, volumes
docker image prune -f                          # untagged images (the running one is tagged)
docker builder prune -f --filter until=168h    # build cache older than a week
```

The build cache makes builds fast; prune it only when space is short. Never use `docker system prune --volumes` or `docker volume prune`: the volumes are the database and the uploads.

## Status and logs

```sh
docker compose ps                 # both containers up, the database "healthy"?
docker compose logs -f app        # the app's log, live
docker compose logs app | grep -i error
docker compose logs app | grep "rate limit reached"   # blocked sign-in attempts
```

Expected problems are also recorded as incidents in the admin area; the log has the technical side.

When someone reaches a limit for sign-in attempts or sign-in emails, the log gets a line in a fixed format, without the email address, e.g. `rate limit reached: bucket=sign_in_ip ip=203.0.113.7`. Tools like fail2ban can filter for it and block the IP on the server.

## System overview in the browser

Administrators find the Phoenix LiveDashboard under **Administration → System** (`/admin/system`): memory, processes, load, operating system data (CPU, memory, disk space) and live metrics (response times, database queries) of the running app. It does not show environment variables and does not allow changes such as killing processes.

## Console

```sh
docker compose exec app bin/mercator remote            # an IEx shell in the running app
docker compose exec app bin/mercator rpc "IO.puts(:ok)" # one command in the running app
```

Use `rpc`, not `eval`: `eval` would start a second instance of the app.

## Backup

The database and the uploads (product images, media library, chat files):

```sh
docker compose exec db pg_dump -U postgres mercator | gzip > mercator-$(date +%F).sql.gz
docker compose run --rm --no-deps --entrypoint tar -v "$PWD":/backup app \
  czf /backup/uploads-$(date +%F).tar.gz -C /data uploads
```

Keep `.env` safe as well; without its secrets, existing sign-in tokens and the database password are lost.

To restore (with the dates of your backup files):

```sh
docker compose stop app
docker compose exec db dropdb -U postgres mercator
docker compose exec db createdb -U postgres mercator
gunzip -c mercator-2026-10-16.sql.gz | docker compose exec -T db psql -U postgres -q mercator
docker compose run --rm --no-deps --entrypoint tar -v "$PWD":/backup app \
  xzf /backup/uploads-2026-10-16.tar.gz -C /data
docker compose up -d
```

The app must be stopped, since the database cannot be dropped while it is connected. The uploads archive is unpacked over the current uploads: files added since the backup stay.

## Starting from scratch

```sh
docker compose down -v
docker compose up -d
```

This deletes the database and all uploads; the app starts with an empty database (in demo mode it seeds itself again).
