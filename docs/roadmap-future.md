# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

Phases 1–9 are done (see [roadmap-history.md](roadmap-history.md)).

- **10 Video advice** ([video-design.md](video-design.md), agreed 2026-10-16): audio, video and screen sharing in the advice conversation, self-hosted with Elixir WebRTC (`ex_webrtc`): an SFU room process in the release, signaling through the chat and desk LiveViews, UDP ports published from Docker. Steps 1 (room process, two-peer test), 2 (`Call` resource, call states, chat lines), 3 (browser side, call UI in chat and desk; tested Firefox ↔ Chrome) and 4 (screen sharing, devices, speaking indicator, full screen; manual test pending) done, plus #150 (the desk call keeps running across conversations) and 5 (deployment; tested on the demo server from mobile data) done; next: step 6, observability (WebRTC dashboard page, telemetry, incidents for failed calls).

## Postponed

- *Nothing right now.*

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- *Empty right now.*

## Open questions

- *None right now.*

