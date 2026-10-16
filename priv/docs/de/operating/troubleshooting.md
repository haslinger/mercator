---
title: Fehlersuche
order: 40
---
| Anzeichen | Ursache und Abhilfe |
|---|---|
| `docker compose` meldet, eine Variable sei „not set“ | `.env` fehlt oder ist unvollständig, siehe [Konfiguration](configuration.md) |
| Die App startet immer wieder neu | `docker compose logs app` nennt die fehlende Einstellung, z. B. `SMTP_RELAY` oder `DEMO_ADMIN_PASSWORD` |
| Die Seite lädt, zeigt aber „reconnecting“ | der Reverse Proxy leitet keine WebSockets weiter (`Upgrade`/`Connection`-Header), oder `PHX_HOST` passt nicht zur Domain |
| Ein Anruf ist angenommen, bleibt aber bei „Verbinde …“ oder zeigt „Die Verbindung ist fehlgeschlagen.“ | die UDP-Pakete kommen nicht an: `CALL_PUBLIC_HOST` fehlt, der Bereich `CALL_PORT_RANGE` ist im Router nicht weitergeleitet oder von der Firewall gesperrt; oder das Netz der Kundin sperrt UDP (siehe [Videoanrufe](calls.md)). Der Vorfall zum fehlgeschlagenen Anruf nennt die Adressen, die beide Seiten angeboten haben |
| Der Anrufbereich meldet, er brauche das Mikrofon | der Browser hat kein Mikrofon oder die Erlaubnis wurde verweigert; Kamera und Mikrofon brauchen außerdem HTTPS (außer auf `localhost`) und gehen nicht in eingebetteten Rahmen wie Entwicklerwerkzeugen |
| HTTPS geht von außen nicht | die Ports 80 und 443 müssen den Reverse Proxy erreichen (Port 80 braucht das Zertifikat); Router und Firewall prüfen, bei einem AAAA-Eintrag auch IPv6 |
| E-Mails kommen nicht an | ein Vorfall mit dem SMTP-Fehler in den technischen Details; typisch: der Absender (`MAIL_FROM_ADDRESS`) ist für das SMTP-Konto nicht erlaubt, oder die Zertifikatsprüfung schlägt fehl |
| Alle sind auf einmal von Ratenlimits betroffen | die App sieht die Adresse des Proxy statt der Besucherinnen und Besucher: `TRUSTED_PROXIES` muss Adresse oder Netz des Proxy enthalten (Vorfälle zu Ratenlimits zeigen die erkannte IP) |
| Ein PDF schlägt fehl | ein Vorfall mit dem Fehler von Typst; die E-Mail geht trotzdem hinaus, ohne PDF |
| `docker compose build` findet das Basis-Image nicht | `UBUNTU_TAG` im `Dockerfile` auf einen aktuellen Tag ändern (Elixir und Erlang wie in `.tool-versions`) |
