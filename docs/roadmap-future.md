# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

Phases 1–9 are done (see [roadmap-history.md](roadmap-history.md)).

*No phase planned right now.*

## Postponed

- **Audio/video and screen sharing** in the advice chat (#100, from phase 6); possible self-hosted with `ex_webrtc`.

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- **Phoenix LiveDashboard for administrators:** today it only runs in development (`/dev/dashboard`). Mount it in production as well, behind the admin sign-in (a pipeline that requires the administrator role, plus `on_mount` with `MercatorWeb.LiveUserAuth` for its LiveView session), and link it from "Verwaltung" in the admin sidebar and dashboard, administrators only. Check what it shows (e.g. request logger, OS data) and leave out what an operator should not see in the browser.

## Open questions

- *None right now.*
