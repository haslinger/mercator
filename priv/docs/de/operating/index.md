---
title: Betrieb
order: 0
---
Mercator läuft als Docker-Image (Mix-Release) neben PostgreSQL, gestartet mit `docker compose`; jede Installation ist ein Shop. Die Einrichtung auf einem Server beschreibt `DOCKER.md` im Repository (Voraussetzungen, Reverse Proxy, erster Start). Diese Kapitel gelten dem laufenden Betrieb:

- [Konfiguration](configuration.md): die Einstellungen in `.env`.
- [Wartung](maintenance.md): Aktualisieren, Logs, Konsole, Sicherung.
- [Demo-Modus](demo.md): die öffentliche Demo mit nächtlichem Zurücksetzen.
- [Fehlersuche](troubleshooting.md).

Probleme, die der Shop selbst bemerkt (E-Mails, die nicht zugestellt wurden, fehlgeschlagene PDFs, Zahlungsprobleme), erscheinen unter **Verwaltung → Vorfälle**.
