# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

Phases 1–10 are done (see [roadmap-history.md](roadmap-history.md)).

*No phase planned right now.*


## Postponed

- *Nothing right now.*

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

*Nothing right now.*

## Open questions

- **#160** The privacy policy says server logs are kept **at most seven days**. That has to be true: `docker-compose.yml` sets no log rotation for the container, and the reverse proxy keeps its own access logs. Add a `logging` section to the compose file and check the proxy's rotation?
- **#161** The imprint shows `stefan.haslinger@informatom.com` (as on informatom.com); spam bots will find it. Keep it, or use a separate address for the demo?
- **#162** The made-up Biber Holz phone number `+43 1 234 56 78` and address `Waldweg 1, 3914 Waldhausen` (brand settings, contact options, footer) could belong to real people or places. Replace them with clearly fictitious ones, or leave out the phone number?
- **#163** § 5 ECG asks for the chamber a business belongs to (e.g. Wirtschaftskammer Wien, Fachgruppe UBIT). informatom.com does not list it; add it to the imprint?

