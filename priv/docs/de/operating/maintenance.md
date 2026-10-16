---
title: Wartung
order: 20
---
Alle Befehle laufen im Verzeichnis mit `docker-compose.yml`.

## Aktualisieren

```sh
docker compose exec db pg_dump -U postgres mercator | gzip > mercator-$(date +%F).sql.gz
docker tag mercator:latest mercator:previous   # die laufende Version für ein Zurücksetzen aufheben
git pull
docker compose build
docker compose up -d
docker image prune -f                          # alte Images ohne Tag löschen
```

Der neue App-Container führt vor dem Start die Datenbankmigrationen aus. Datenbank und Uploads bleiben erhalten. Für ein Update **nicht** `docker compose down -v` verwenden: `-v` löscht die Volumes, also die Datenbank und alle Uploads.

Vorher sichern: Migrationen ändern die Datenbank und werden nicht rückgängig gemacht. Jeder Build bekommt den Tag `mercator:latest`; das Image davor verliert seinen Tag und bleibt auf der Platte, bis `docker image prune` es löscht. `mercator:previous` ist ein Tag und bleibt daher erhalten: Es gibt immer eine Version, zu der Sie zurückkehren können. Beim allerersten Update schlägt `docker tag` fehl, weil es noch kein `mercator:latest` gibt; das ist in Ordnung.

## Zurücksetzen auf die vorige Version

```sh
docker tag mercator:previous mercator:latest
docker compose up -d --no-build
```

Hat das Update Migrationen ausgeführt, läuft die alte Version mit der neuen Datenbank womöglich nicht: Spielen Sie dann auch die Sicherung von vor dem Update ein (siehe Sicherung). Checken Sie vor dem nächsten Build den alten Commit wieder aus, denn `git pull` hat den Stand weiterbewegt.

## Speicherplatz

```sh
docker system df                               # Images, Build-Cache, Volumes
docker image prune -f                          # Images ohne Tag (das laufende hat einen)
docker builder prune -f --filter until=168h    # Build-Cache, älter als eine Woche
```

Der Build-Cache macht Builds schnell; leeren Sie ihn nur, wenn der Platz knapp wird. Verwenden Sie nie `docker system prune --volumes` oder `docker volume prune`: Die Volumes sind die Datenbank und die Uploads.

## Zustand und Logs

```sh
docker compose ps                 # beide Container laufen, die Datenbank "healthy"?
docker compose logs -f app        # das Log der App, laufend
docker compose logs app | grep -i error
```

Erwartbare Probleme stehen zusätzlich als Vorfälle in der Verwaltung; das Log zeigt die technische Seite.

## Systemübersicht im Browser

Administratoren finden unter **Verwaltung → System** (`/admin/system`) das Phoenix LiveDashboard: Speicher, Prozesse, Auslastung, Betriebssystemdaten (CPU, Arbeitsspeicher, Plattenplatz) und laufende Messwerte (Antwortzeiten, Datenbankabfragen) der laufenden App. Es zeigt keine Umgebungsvariablen und erlaubt keine Eingriffe wie das Beenden von Prozessen.

## Konsole

```sh
docker compose exec app bin/mercator remote            # eine IEx-Shell in der laufenden App
docker compose exec app bin/mercator rpc "IO.puts(:ok)" # ein Befehl in der laufenden App
```

`rpc` verwenden, nicht `eval`: `eval` würde eine zweite Instanz der App starten.

## Sicherung

Datenbank und Uploads (Produktbilder, Mediathek, Chat-Dateien):

```sh
docker compose exec db pg_dump -U postgres mercator | gzip > mercator-$(date +%F).sql.gz
docker compose run --rm --no-deps --entrypoint tar -v "$PWD":/backup app \
  czf /backup/uploads-$(date +%F).tar.gz -C /data uploads
```

Bewahren Sie auch `.env` sicher auf; ohne ihre Geheimnisse sind bestehende Anmeldungen und das Datenbankpasswort verloren.

Wiederherstellen (mit dem Datum Ihrer Sicherungsdateien):

```sh
docker compose stop app
docker compose exec db dropdb -U postgres mercator
docker compose exec db createdb -U postgres mercator
gunzip -c mercator-2026-10-16.sql.gz | docker compose exec -T db psql -U postgres -q mercator
docker compose run --rm --no-deps --entrypoint tar -v "$PWD":/backup app \
  xzf /backup/uploads-2026-10-16.tar.gz -C /data
docker compose up -d
```

Die App muss dabei gestoppt sein, denn solange sie verbunden ist, lässt sich die Datenbank nicht löschen. Das Uploads-Archiv wird über die vorhandenen Uploads entpackt: Dateien, die seit der Sicherung dazugekommen sind, bleiben.

## Neu beginnen

```sh
docker compose down -v
docker compose up -d
```

Das löscht die Datenbank und alle Uploads; die App startet mit leerer Datenbank (im Demo-Modus befüllt sie sich wieder selbst).
