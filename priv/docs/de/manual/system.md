---
title: System
roles: [administrator]
order: 140
---
**Verwaltung → System** öffnet das [Phoenix LiveDashboard](https://hexdocs.pm/phoenix_live_dashboard) in einem neuen Tab: einen Blick in die laufende App, nur für Administratoren. Es hat eine eigene, englische Oberfläche und keinen Weg zurück in die Verwaltung; schließen Sie den Tab, wenn Sie fertig sind.

Die Werte sind live und werden nicht gespeichert: Die Diagramme beginnen leer, wenn Sie die Seite öffnen, und füllen sich, solange sie offen ist.

| Seite | Was sie zeigt | Wofür |
|---|---|---|
| **Home** | Versionen (Elixir, Erlang, Phoenix), Laufzeit seit dem letzten Start, Speicher und Prozesse im Überblick | Läuft die App, seit wann? |
| **OS Data** | CPU-Last, Arbeitsspeicher und Plattenplatz des Servers | Wird der Platz knapp (z. B. durch Uploads oder alte Docker-Images)? |
| **Metrics** | Antwortzeiten der Seiten, Dauer der Datenbankabfragen, Speicher und Warteschlangen der Laufzeitumgebung, begonnene und beendete Anrufe | Ist der Shop langsam, und liegt es an der Datenbank? |
| **Ecto Stats** | Die Datenbank: Größe der Tabellen und Indizes, ungenutzte Indizes, Cache-Trefferquote, Sperren, lang laufende Abfragen, Vacuum-Statistik | Wächst die Datenbank, fehlt ein Index, hängt eine Abfrage? |
| **WebRTC** | Die Verbindungen laufender Videoanrufe: Bitrate, Paketverluste, Laufzeit, die ausgehandelten Verbindungsdaten (mit den IP-Adressen der Teilnehmenden) | Ruckelt ein Anruf, und auf welcher Seite? |
| **Memory Allocators**, **Applications**, **Processes**, **Ports**, **Sockets**, **ETS** | Interna der Laufzeitumgebung | Fehlersuche mit Entwicklern |

Bewusst weggelassen: Umgebungsvariablen (sie enthalten Geheimnisse), der Request-Logger und Eingriffe wie das Beenden von Prozessen oder Datenbankverbindungen. Das Dashboard verändert also nichts.

In Docker zeigt **OS Data** CPU und Arbeitsspeicher des Servers, die Platten so, wie der Container sie sieht. Wie Sie Platz schaffen, steht unter Betrieb → Wartung.
