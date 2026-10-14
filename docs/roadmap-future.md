# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

6. **Guided selling** – in progress ([guided-selling-design.md](guided-selling-design.md), #94–#101 agreed):
   - done: step 1 conversations and the customer's chat; step 2 the sales desk with availability, taking conversations, countdown and callback requests (#95); step 3 customer context on the desk (online, current page, basket, orders), product recommendations, links and files as cards (#96)
   - done: step 4 offers in the back office (Offer/OfferItem, /admin/offers editor, approval #98, revisions, desk integration)
   - done: step 5 offers for customers (/account/offers, card in the chat, accept → checkout with the offer as source, order refers to the offer)
   - done: step 6 emails (#97), printable offer page (#99), ratings (#101)
   - next: step 7 demo data (conversations, offers)
   - postponed: audio/video and screen sharing (#100; possible self-hosted with `ex_webrtc`)
7. **Integrations:** online payment with a provider still to be chosen (replacing mPAY24, #14). Mesonic, Icecat and Bechlem are out of scope (#15).
8. **Deployment and demo mode:** a Mix release in a **Docker** image (#24; details such as the Postgres setup and the image registry to be decided in this phase), demo mode `MERCATOR_MODE=demo` with public demo accounts and nightly reset (#44–#48), production email delivery, reverse proxy rate limits (README).

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- **Product editor: tabs by product kind** (2026-10-13). The tabs shown should follow the kind chosen on the "General" tab, and react as soon as it is changed, not only after saving (today only the "Configurator" tab is hidden, for non-configurable products, based on the saved kind).
  - *simple:* "Variants & prices" reduced to the one variant (no adding variants), e.g. as "Price & stock".
  - *configurable:* no prices in the variants tab (the price comes from the configurator); only number, unit, delivery time and active remain, or the tab is hidden and those fields move to "General" / "Configurator".
  - Changing the kind of an existing product needs a rule for data that no longer fits (extra variants, prices, options): warn, keep or delete.
- **Start page key for content managers** (2026-10-14): only administrators can set a page's key (e.g. `home`). Content managers may need a simple "use as start page" action.
- **Active entry in the shop sidebar** (2026-10-14): the sidebar does not highlight the current page or category yet (the admin sidebar does).
- **PDF documents with Typst** (#17, decided): offers and order confirmations as PDF files. Then the offer pages get a "PDF erstellen" button next to "Drucken" (today the browser's print dialog can save as PDF), and the PDFs can be attached to the offer and confirmation emails.
- **Variants combined with a configurator** (not possible today, see #39/#55): e.g. a panel in stock in three species that can also be cut to size. Workaround: two related products. Only if a customer needs it.

## Open questions

- *No open questions right now.*
