# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

6. **Guided selling** – done 2026-10-15 (see [roadmap-history.md](roadmap-history.md)); still open from it:
   - postponed: audio/video and screen sharing (#100; possible self-hosted with `ex_webrtc`)
7. **Integrations:** online payment with a provider still to be chosen (replacing mPAY24, #14). Mesonic, Icecat and Bechlem are out of scope (#15).
8. **Deployment and demo mode:** a Mix release in a **Docker** image (#24; details such as the Postgres setup and the image registry to be decided in this phase), demo mode `MERCATOR_MODE=demo` with public demo accounts and nightly reset (#44–#48), production email delivery, reverse proxy rate limits (README).

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- **Product editor: tabs by product kind** (2026-10-13). The tabs shown should follow the kind chosen on the "General" tab, and react as soon as it is changed, not only after saving (today only the "Configurator" tab is hidden, for non-configurable products, based on the saved kind).
  - *simple:* "Variants & prices" reduced to the one variant (no adding variants), e.g. as "Price & stock".
  - *configurable:* no prices in the variants tab (the price comes from the configurator); only number, unit, delivery time and active remain, or the tab is hidden and those fields move to "General" / "Configurator".
  - Changing the kind of an existing product needs a rule for data that no longer fits (extra variants, prices, options): warn, keep or delete.
- **PDF documents with Typst** (#17, decided): offers and order confirmations as PDF files. Then the offer pages get a "PDF erstellen" button next to "Drucken" (today the browser's print dialog can save as PDF), and the PDFs can be attached to the offer and confirmation emails.

## Open questions

- *No open questions right now.*
