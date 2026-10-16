---
title: Wartung
order: 20
---
Alle Befehle laufen im Verzeichnis mit `docker-compose.yml`.

## Aktualisieren

```sh
git pull
docker compose build
docker compose up -d
```

Der neue App-Container führt vor dem Start die Datenbankmigrationen aus. Datenbank und Uploads bleiben erhalten. Für ein Update **nicht** `docker compose down -v` verwenden: `-v` löscht die Volumes, also die Datenbank und alle Uploads.

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

## Neu beginnen

```sh
docker compose down -v
docker compose up -d
```

Das löscht die Datenbank und alle Uploads; die App startet mit leerer Datenbank (im Demo-Modus befüllt sie sich wieder selbst).
