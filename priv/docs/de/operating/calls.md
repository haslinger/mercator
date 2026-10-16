---
title: Videoanrufe
order: 25
---
Beraterinnen und Berater rufen Kundinnen und Kunden direkt aus dem Beratungsgespräch an: Audio, Video und Bildschirm teilen. Die Medien laufen über den Server der App, nicht über einen fremden Dienst, und werden nicht aufgezeichnet.

Damit das von außen funktioniert, braucht es drei Dinge außer HTTPS:

1. **Die öffentliche Adresse:** `CALL_PUBLIC_HOST` in `.env`, meist derselbe Name wie `PHX_HOST`. Im Container kennt die App nur ihre Container-Adresse; mit dieser Einstellung bietet sie den Browsern die öffentliche an. Der Name wird bei jedem Anruf neu aufgelöst, eine wechselnde IP hinter DynDNS ist also kein Problem.
2. **Die UDP-Ports im Router:** die Medien gehen nicht über den Reverse Proxy, sondern direkt per UDP an die Ports `CALL_PORT_RANGE` (Standard 50000–50049). Leiten Sie diesen Bereich im Router an den Server weiter, mit denselben Portnummern.
3. **Die Firewall:** Docker veröffentlicht die Ports mit eigenen Regeln, die vor denen von ufw greifen; ohne weitere Maßnahmen ist der Bereich also offen. Mit den [ufw-docker](https://github.com/chaifeng/ufw-docker)-Regeln entscheidet ufw, und eine Regel genügt, beschränkt auf den App-Container mit seiner festen Adresse (`APP_IP`, Standard `172.30.0.10`):

```sh
sudo ufw route allow proto udp from any to 172.30.0.10 port 50000:50049 comment mercator-calling
```

Nach einer Änderung an `.env` oder `docker-compose.yml`: `docker compose up -d`.

## Ausprobieren

Zwei Browser, einer davon außerhalb des eigenen Netzes (z. B. ein Handy im Mobilfunknetz): als Kundin ein Gespräch beginnen, am Beratungsplatz annehmen und **Videoanruf** wählen. Bleibt der Anruf bei „Verbinde …“ stehen, kommen die UDP-Pakete nicht an, siehe [Fehlersuche](troubleshooting.md).

## Bandbreite

Jedes Bild geht einmal zum Server und von dort zur anderen Seite. Ein Videoanruf braucht am Server etwa 2–4 Mbit/s in jede Richtung, ein geteilter Bildschirm zeitweise mehr. Für einen Anschluss zu Hause reicht das für einen oder zwei Anrufe gleichzeitig.

## Was die App nicht macht

Kein TURN-Server: Netze, die UDP ganz sperren (manche Firmen, Hotels), erreichen den Anruf nicht. Ein Anruf, dessen Verbindung fehlschlägt, endet im Gesprächsverlauf mit „Der Anruf konnte nicht verbunden werden.“ und wird ein Vorfall; seine technischen Details zeigen, welche Adressen beide Seiten angeboten haben und ob Prüfpakete angekommen sind. Häufen sich solche Vorfälle, kann ein TURN-Server nachgerüstet werden.

Die laufenden Verbindungen zeigt **Verwaltung → System → WebRTC**: Bitrate, Paketverluste und Laufzeit je Seite.
