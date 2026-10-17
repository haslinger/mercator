---
title: Konfiguration
order: 10
---
Alles Geheime und Installationsspezifische steht in der Datei `.env` neben `docker-compose.yml`; nichts davon steckt im Image oder im Repository. Nach einer Änderung genügt `docker compose up -d`: Compose erstellt den App-Container neu, ein Build ist nicht nötig.

| Variable | Bedeutung |
|---|---|
| `POSTGRES_PASSWORD` | Datenbankpasswort, für beide Container |
| `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET` | zwei verschiedene Geheimnisse, je aus `openssl rand -base64 48` |
| `PHX_HOST` | die öffentliche Domain, z. B. `shop.example.com`; für Links in E-Mails, PDFs und auf Bezahlseiten |
| `APP_PORT` | Port auf `127.0.0.1`, an den der Reverse Proxy weiterleitet (Standard 4010) |
| `TRUSTED_PROXIES` | Adressen oder Netze des Reverse Proxy, dessen `X-Forwarded-For` geglaubt wird (Standard Dockers `172.16.0.0/12`); nötig für die Client-IP bei den Ratenlimits |
| `SMTP_RELAY`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | der Mailserver; Port 465 (TLS) oder 587 (STARTTLS). Ohne `SMTP_RELAY` startet die App nicht |
| `SMTP_TLS_VERIFY` | `false` nur, wenn sich das Zertifikat des Mailservers nicht prüfen lässt |
| `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | Absender aller E-Mails; eine Adresse, mit der das SMTP-Konto senden darf |
| `BRAND` | die Marke (Name, Logo, Farben, Kontaktdaten) aus `config/brands/`, z. B. `biberholz`; leer für das neutrale Mercator-Aussehen |
| `SHOP_TIME_ZONE` | Zeitzone des Shops (Standard `Europe/Vienna`): Zeiten auf Seiten und in E-Mails, „heute“ für Preisgültigkeiten, die nächtlichen Aufgaben |
| `MOLLIE_API_KEY` | Mollie für Online-Zahlung: `test_…` simuliert Zahlungen, `live_…` bucht echtes Geld. Danach unter Verwaltung → Zahlungsanbieter einschalten |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` | Benachrichtigungen aufs Handy (Web Push): das Schlüsselpaar des Shops, erzeugt mit `mix mercator.gen.vapid`; kostenlos, kein Konto nötig. Ohne sie gibt es keine Benachrichtigungen. Ein neues Paar heißt: alle schalten sie am Beratungsplatz neu ein |
| `VAPID_SUBJECT` | optional: Kontakt für die Push-Dienste, z. B. `mailto:shop@example.com` (Standard: `MAIL_FROM_ADDRESS`) |
| `MERCATOR_MODE` | `demo` für die öffentliche Demo, leer für einen echten Shop (siehe [Demo-Modus](demo.md)) |
| `DEMO_ADMIN_PASSWORD` | nur Demo: das Passwort der Administration, mindestens 8 Zeichen |
| `CONSULTING_WAIT_SECONDS` | Beratung: Sekunden, die eine Kundin oder ein Kunde auf eine Beraterin oder einen Berater wartet, bevor der Rückruf angeboten wird (Standard `180`) |
| `CALL_PUBLIC_HOST` | Videoanrufe: der öffentliche Name (oder die IP), unter dem die Browser die Medien erreichen, meist wie `PHX_HOST`; ohne ihn gehen Anrufe nur im eigenen Netz (siehe [Videoanrufe](calls.md)) |
| `CALL_PORT_RANGE` | Videoanrufe: die UDP-Ports für die Medien (Standard `50000-50049`), mit denselben Nummern veröffentlicht |
| `CALL_ICE_SERVERS` | Videoanrufe: optionale STUN-Server, mit Komma getrennt, z. B. `stun:stun.example.org:3478` |
| `MERCATOR_SUBNET`, `APP_IP` | Docker-Netz und feste Adresse der App (Standard `172.30.0.0/24`, `172.30.0.10`); beide ändern, wenn das Netz mit einem anderen auf dem Host kollidiert |

## Einstellungen in der Verwaltung

Manches steht nicht in `.env`, sondern in der Verwaltung, für die Administration: der aktive Zahlungsanbieter, Benutzer und Rollen, Steuerklassen. Versandkosten, Zahlungsarten und Lieferländer gehören zur Konfiguration des Shops im Code (`config/config.exs` und die Marke) und ändern sich mit einem neuen Release.
