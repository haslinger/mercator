---
title: Overview
order: 0
---
Mercator is a guided-selling web shop with a CMS: customers shop on their own or are advised in a live chat that can end in an offer. It is written in Elixir with Phoenix 1.8, Ash 3, LiveView and DaisyUI 5 (Tailwind 4) on PostgreSQL, and is a port of the Rails/Hobo application of the same name (2013–2017).

## One deployment per customer

Mercator is a generic product, installed once per customer (single tenant). What differs per customer comes from outside the code:

- **runtime configuration** (`.env`, read in `config/runtime.exs`), see the operating part;
- a **brand** in `config/brands/` (name, logo, DaisyUI themes, contact and bank data), chosen with `BRAND`;
- the registered **payment providers**, switched by administrators.

## Domains

| Domain | Resources | Purpose |
|---|---|---|
| `Mercator.Accounts` | User, Address, Token | sign-in (password and magic link), roles, address book |
| `Mercator.Catalog` | Category, Product, Variant, Price, ProductOption, OptionChoice, Image, Property…, ProductRelation, TaxClass | the range, prices, the configurator (`Mercator.Catalog.Configurator`) |
| `Mercator.Sales` | Basket, BasketItem, Order, OrderItem, OrderEvent, OnlinePayment, Gtc | basket, checkout (`Mercator.Sales.Checkout`), orders and their states, terms |
| `Mercator.Consulting` | Conversation, Message, Offer, OfferItem | chat, sales desk, offers |
| `Mercator.Content` | Page, PageRedirect, Submission, Asset | CMS pages made of blocks, media library, contact form |
| `Mercator.Operations` | Incident, Setting | incidents, settings changed at runtime |

Around them: `Mercator.Payments` (providers: Mollie, the simulator), `Mercator.Docs` (this documentation, compiled in), `Mercator.Demo` (demo mode), `Mercator.Seeds` (the Biber Holz demo data), `Mercator.Pdf` (Typst).

## Patterns

- **Ash for all data:** resources with AshPostgres, actions called through the domains' code interfaces, permissions as Ash policies with the signed-in user as actor. State machines with AshStateMachine (orders, offers, pages), history with AshPaperTrail where it matters (pages).
- **Translated content** is one JSONB map per field (`%{"de" => …, "en" => …}`, `Mercator.Translated`); UI texts use Gettext. German is the default, English the second language.
- **Money** is `Decimal`, net in the database; VAT comes from tax classes.
- **LiveView first:** every page is a LiveView; plain controllers only for files (PDFs, uploads), webhooks, sitemap and sign-in callbacks.
- **Background work** with Oban (emails, nightly jobs); jobs that fail for good become incidents.
- **Real time** with Phoenix PubSub and Presence (chat, sales desk, basket, incident badge).

## Where to read on

The design documents in this part describe each phase with its decisions (`#N`, numbered across the project); the roadmap history lists all decisions, the roadmap future what is open. [Working on the code](working.md) explains the daily workflow.
