---
title: Overview
order: 0
---
Mercator is a guided-selling web shop with a CMS, written in Elixir with Phoenix 1.8, Ash 3, LiveView and DaisyUI 5 on PostgreSQL. It is a port of the Rails/Hobo application of the same name.

- **Domains:** Accounts, Catalog, Sales (basket, checkout, orders), Consulting (conversations, offers), Content (CMS) and Operations (incidents, settings).
- **One deployment per customer:** customer specifics come from runtime configuration, a brand (logo, theme, texts) and the registered payment providers.
- **Decisions** are numbered (`#N`) and recorded in the roadmap history; each phase has its own design document, listed in this part.
- **Conventions** for working on the code are in `CLAUDE.md` and `AGENTS.md` in the repository.
