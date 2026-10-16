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

- **Phone notifications for sales** *(noted 2026-10-16)*: notify consultants on their (Android) phones about new conversations and call requests, also when the desk is not open. Options: (1) **Web Push** from the shop itself (VAPID, the existing service worker `priv/static/sw.js`; Chrome on Android shows it with the browser closed; iOS only for the PWA on the home screen; no extra server); (2) self-hosted **ntfy** (priorities, click URL, actions, Android and iOS apps) or **Gotify** (Android only): one HTTP POST from an Oban job, but one more container and an app per phone; (3) a native app with Firebase (not worth it). Proposal: Web Push as the default behind a small notification module, ntfy/Gotify later as an optional module per customer. Open: #151–#153.

## Open questions

- **#151** Phone notifications: about what (new waiting conversations, call requests, callback requests), and when: only for available consultants, or with the desk closed too via a per-user "notify me on my phone" switch (proposal), possibly within a time window such as business hours?
- **#152** Web Push as the default channel, ntfy/Gotify only on demand as an optional module?
- **#153** Who is notified: everyone with notifications on at the same time (like the desk now), or one after another (like the Rails app)?

