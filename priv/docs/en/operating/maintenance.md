---
title: Maintenance
order: 20
---
All commands run in the directory with `docker-compose.yml`.

## Updating

```sh
git pull
docker compose build
docker compose up -d
```

The new app container runs the database migrations before it starts. The database and the uploads stay. Do **not** use `docker compose down -v` for an update: `-v` deletes the volumes, i.e. the database and all uploads.

## Status and logs

```sh
docker compose ps                 # both containers up, the database "healthy"?
docker compose logs -f app        # the app's log, live
docker compose logs app | grep -i error
```

Expected problems are also recorded as incidents in the admin area; the log has the technical side.

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

## Starting from scratch

```sh
docker compose down -v
docker compose up -d
```

This deletes the database and all uploads; the app starts with an empty database (in demo mode it seeds itself again).
