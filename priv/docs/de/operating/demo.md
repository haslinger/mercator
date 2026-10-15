---
title: Demo-Modus
order: 30
---
Mit `MERCATOR_MODE=demo` ist die Installation eine öffentliche Demo (wie die Biber-Holz-Demo). Ein Schalter aktiviert alles Demo-Spezifische:

- **Befüllen:** beim ersten Start mit leerer Datenbank lädt die App die Demodaten: Katalog mit Fotos, Seiten, Bestellungen, Gespräche, Angebote und Demo-Benutzer (dauert etwa eine Minute).
- **Demo-Benutzer:** die Administration bekommt `DEMO_ADMIN_PASSWORD` und wird nie öffentlich gezeigt. Alle anderen haben das Passwort `mercator-demo`; die Anmeldeseite bietet sie als Ein-Klick-Knöpfe an, ohne Adressen oder Passwort zu zeigen. Sie können Passwort und Rollen nicht ändern und kein neues Passwort anfordern.
- **Zahlung:** der Zahlungssimulator ist der aktive Anbieter; niemand zahlt echtes Geld.
- **Nächtliches Zurücksetzen um 03:00** (Shop-Zeit): alle Tabellen werden geleert (auch Konten, die Besucherinnen und Besucher angelegt haben), Uploads gelöscht und die Demodaten neu geladen.
- **Making-of:** die Sitzungsprotokolle und Projektkennzahlen unter `/making-of`, verlinkt in der Fußzeile.
- Ein **Demo**-Zeichen in der Kopfzeile.

## Von Hand

```sh
docker compose exec app bin/mercator rpc "Mercator.Demo.reset()"     # jetzt zurücksetzen
docker compose exec app bin/mercator rpc "Mercator.Release.seed()"   # erneut befüllen, ohne zu leeren
```

Ist das Befüllen beim ersten Start halb stehen geblieben, befüllt ein Neustart nicht erneut (es gibt schon Benutzer); der Befehl zum Zurücksetzen behebt das.

Eine Änderung von `DEMO_ADMIN_PASSWORD` wirkt mit dem nächsten Zurücksetzen, denn das Passwort wird beim Anlegen des Kontos gesetzt.
