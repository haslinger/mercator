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
8. **Deployment and demo mode** – design in progress ([deployment-design.md](deployment-design.md), #114–#117 decided, #118–#119 open): Docker image with `typst` and fonts, built on the home server, behind its reverse proxy; demo mode `MERCATOR_MODE=demo` with public demo accounts and nightly reset (#44–#48); SMTP; reverse proxy rate limits (README).

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- *Empty right now.*

## Open questions

- #118–#119 (deployment): see [deployment-design.md](deployment-design.md#7-open-questions).
