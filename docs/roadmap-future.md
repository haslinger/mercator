# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

6. **Guided selling** – done 2026-10-15 (see [roadmap-history.md](roadmap-history.md)); still open from it:
   - postponed: audio/video and screen sharing (#100; possible self-hosted with `ex_webrtc`)
7. **Online payment** – working with the payment simulator (steps 0–2 of [payment-design.md](payment-design.md) done, #108–#113). Still to do, after phase 8:
   - step 3: Mollie adapter (needs a Mollie account and `MOLLIE_API_KEY`), webhook test on the home server
   - step 4: back office (payment attempts on the order, refund on cancel, unpaid filter), "payment received" email
   - later: Stripe; an embedded payment form as a third provider (#109)
   - Mesonic, Icecat and Bechlem are out of scope (#15).
8. **Deployment and demo mode** ([deployment-design.md](deployment-design.md), #114–#119 decided): steps 1 (Docker image, compose, SMTP, DOCKER.md) and 2 (demo mode `MERCATOR_MODE=demo`: seeding at start, public demo logins on the sign-in page, protected demo accounts, badge, simulator, nightly reset; #44–#48) done. Next: step 3, deployment on the home server (by you, with DOCKER.md), then step 4 Mollie (phase 7 step 3); reverse proxy rate limits (README).

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- *Empty right now.*

## Open questions

- **#120** (2026-10-15) The authentication emails (confirmation, password reset, magic link) are sent synchronously inside the action: when SMTP fails, the registration is rolled back, the page crashes and no incident is recorded (seen on the home server). Options: (a) send them through Oban like all other emails (retries, incident at the end), with the token in the job args until pruned (≤ 1 day), or the job stores only the user and builds a fresh link; (b) keep sending directly, catch the error, show a message and report an incident.
