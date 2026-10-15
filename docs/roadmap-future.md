# Mercator – Roadmap: future

What is **still to be done and to be decided**. What has been done and decided: [roadmap-history.md](roadmap-history.md).

Questions are numbered globally (`#N`); the numbering is never restarted. When a question is answered, it moves to the history as a decision.

## Next phases

Phases 1–8 are done (see [roadmap-history.md](roadmap-history.md)).

9. **Documentation** – designed ([documentation-design.md](documentation-design.md), #121–#125, #131–#133): the documentation goes into the product itself, as Markdown in the repo, compiled into the app from where the files are (`priv/docs/<locale>/…`, `docs/*-design.md`, `docs/sessions/`), German and English with German fallback.
   - **Admin area:** a "Hilfe" section in the sidebar (table of contents, search) plus a "?" on each admin page that opens the matching chapter. Audiences: the shop owner and staff (back office manual by role: administration, sales, sales management, content, products; chapters filtered by the user's roles), operators (deployment, updates, backups, demo; today `DOCKER.md`) and developers (architecture, porting conventions, designs; today `docs/*.md`).
   - Operator and developer chapters are visible to administrators only (#125).
   - **Shop:** generic help for visitors (ordering, account, payment, chat and offers) from the repo at `/help`, linked from the footer, the checkout and the chat; customer-specific content (delivery areas, FAQ, GTC) stays in the CMS (#125).
   - **Making-of:** the cleaned session logs and the project metrics, public in the demo at `/making-of` (#131–#133): part of the product is showing how a port with AI works.
   - Sources to reuse: `README.md`, `DOCKER.md`, `docs/*-design.md`, the German Rails wiki (`mercator.wiki`, e.g. the sales-process diagram).

## Postponed

- **Audio/video and screen sharing** in the advice chat (#100, from phase 6); possible self-hosted with `ex_webrtc`.

## Backlog

Smaller improvements noted along the way, not tied to a phase step.

- *Empty right now.*

## Open questions

- *None right now.*
