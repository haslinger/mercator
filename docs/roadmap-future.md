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

- **Phone notifications for sales** *(noted 2026-10-16)*: notify consultants on their (Android) phones about new conversations and call requests, also when the desk is not open. Options: (1) **Web Push** from the shop itself (VAPID, the existing service worker `priv/static/sw.js`; Chrome on Android shows it with the browser closed; iOS only for the PWA on the home screen; no extra server); (2) self-hosted **ntfy** (priorities, click URL, actions, Android and iOS apps) or **Gotify** (Android only): one HTTP POST from an Oban job, but one more container and an app per phone; (3) a native app with Firebase (not worth it). Proposal: Web Push as the default behind a small notification module, ntfy/Gotify later as an optional module per customer. Decided (#151–#153): Web Push; notify about new conversations (all consultants with notifications on, at the same time) and about customer messages in a conversation (only its consultant). Delivery: send as **urgent** (Android's Doze mode holds back normal messages), with a **short TTL** of about 15 minutes so stale "customer waiting" messages are dropped; a setup note for staff (allow notifications, exempt Chrome from battery optimisation). The subscription belongs to the device, not the session, and is deleted on sign-out. No Google account or costs: VAPID keys are our own. Delivery is best effort without receipts, so the desk ringing and the callback form after `consulting_wait_seconds` (120 s) stay the safety net.

## Open questions

*None right now.*

