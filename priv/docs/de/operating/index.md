---
title: Betrieb
order: 0
---
Mercator läuft als Docker-Image (Mix-Release) mit PostgreSQL, gestartet mit `docker compose`. Jede Installation ist ein eigener Shop (eine Kundin, ein Kunde pro Installation).

- **Konfiguration:** alles Geheime und Standortspezifische steht in der Datei `.env` neben `docker-compose.yml`.
- **Aktualisieren:** `git pull && docker compose build && docker compose up -d`. Datenbank und Uploads bleiben erhalten, Migrationen laufen beim Start.
- **Probleme**, die der Shop selbst bemerkt, erscheinen unter Verwaltung → Vorfälle.
