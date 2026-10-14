# Guided selling design (phase 6) — draft

Status: **draft, 2026-10-14.** Open questions #94–#101 are in section 6.

## 1. Goal

What set Mercator apart from a plain shop: customers can talk to a consultant while they shop, and the consultant can recommend products, show pages, share documents and make an **individual offer**, which the customer orders with one click. For Biber Holz: "Wie viel Lärche brauche ich für 40 m² Terrasse?", "Machen Sie mir ein Angebot für das Gartenhaus inklusive Fundament und Lieferung?"

## 2. What the Rails app did

From the models, the sales subsite and the sales process diagram (`mercator.wiki/images/verkaufsprozess.png`):

| Rails | What it did |
|---|---|
| `Conversation` | Customer, consultant, name; started from the shop; has messages, links, downloads, suggestions, offers |
| `Message` | Text chat between customer, consultant and a "robot" sender; realtime via Faye (private_pub) |
| Consultant assignment | Consultants log in to the sales desk (`logged_in`, `call_priority`); a new conversation rang the available consultants one after the other (5 s each); nobody → the robot apologised |
| `Link` (cobrowsing) | The consultant sent a URL; the customer's browser opened it |
| `Download` | Files (photos, documents) shared in the conversation |
| `Suggestion` | Products recommended by the consultant, shown in the conversation |
| Audio/video chat | A link to an external WebRTC service (palava) |
| `Feedback` | The customer could leave feedback on a conversation |
| `Offer` + `Offeritem` | Billing/shipping address, validity date, items (from products or free text, price, VAT, delivery time, per-item discount), overall discount; states in progress → pending approval → valid → invalid (expired) → revised; accepted offers became an order |

## 3. Proposal: one domain `Mercator.Consulting`

### 3.1 Conversations and messages

- **Conversation:** customer (a signed-in user, or a visitor session like the basket, #94), consultant (staff with the `sales` role), subject (optional, e.g. "Gartenhaus Kompakt"), the page it was started from, state `waiting` (no consultant yet) / `active` / `closed`, last activity.
- **Message:** sender (customer, consultant, or system), text, optional attachment (image or PDF, stored like media library files), read flag per side.
- **Realtime** with Phoenix PubSub + LiveView: no extra service. Typing indicator and read receipts are cheap to add.
- **Customer side:** a chat panel that can be opened on every shop page ("Beratung"), plus a prominent "Beraten lassen" button on product pages (starting the conversation with the product as subject). The conversation stays open while the customer moves through the shop.
- **Offline:** if no consultant answers, the conversation simply waits; customers get an email when the reply comes and they are not online (#97).

### 3.2 The sales desk (back office)

- `/admin/desk` for `sales` / `sales_manager`: a status switch **available / away**, the queue of waiting conversations, "my" conversations and all open ones.
- **Assignment (#95):** a new conversation notifies all available consultants (sound + browser notification while the desk is open); the first one to take it gets it. Others can still join or take over.
- **Conversation view** for the consultant: the chat, and next to it the customer context: **current page** in the shop (live), **basket** contents, previous **orders**, earlier conversations, addresses.
- **Recommend a product:** search, then post it into the chat as a product card with "In den Warenkorb" (for configurable products with a prepared configuration).
- **Show a page** (#96, the Rails "cobrowsing"): the consultant sends a page; the customer sees it in the chat and opens it with one click (no remote control of the customer's browser).
- **Share files:** images and PDFs in the chat.

### 3.3 Offers

- **Offer:** customer, consultant, conversation (optional), number (like order numbers, e.g. `BH-A-2026-00012`), validity date, items, overall discount, note, addresses (from the customer's address book).
- **Offer item:** a product variant (with configuration for configurable products, priced by the configurator) **or** a free-text position (e.g. "Fundament, Montage"), quantity, unit, unit price (from the price list, overridable), discount per item, VAT rate, delivery time.
- **States** (AshStateMachine): `draft` → (`pending_approval` →) `sent` → `accepted` / `expired` / `withdrawn`; a sent or expired offer can be **revised** into a new draft version (the history of versions stays).
- **Approval (#98):** offers whose discount exceeds a limit need a sales manager's approval before they are sent.
- **Customer side:** sent offers in the account (`/account/offers`) and as a card in the conversation; "Angebot annehmen" puts the items into the basket **at the offer's prices**, and the normal checkout (addresses, shipping, payment, GTC) follows; the order refers to the offer.
- **PDF (#99):** a printable offer document.

### 3.4 What we leave out or postpone

- **Audio/video chat (#100):** later, or a link to an external video service.
- **Feedback on conversations (#101).**
- Real co-browsing (the consultant sees the customer's screen) – not planned; "current page" and "show a page" cover the common case.

## 4. Resources (domain `Mercator.Consulting`)

`Conversation`, `Message`, `Offer`, `OfferItem`, plus a presence of available consultants (Phoenix.Presence, not a table). Policies: customers see their own conversations and sent offers; `sales` sees and works on conversations and offers; `sales_manager` approves; administrators everything.

## 5. Implementation order (one commit each, with tests)

1. Consulting domain: Conversation and Message; customer chat panel (signed-in customers and visitors, #94), realtime.
2. Sales desk: availability (presence), queue, taking conversations, chat, notifications in the desk.
3. Customer context for the consultant (current page, basket, orders), product recommendations, "show a page", files.
4. Offers: resource and editor in the desk (products, configurations, free positions, discounts, approval).
5. Offers for customers: account and conversation, accept → basket at offer prices → checkout; order refers to the offer.
6. Emails: reply notifications for offline customers, offer sent, approval requests; PDF (#99).
7. Biber Holz demo data: a few conversations and offers.

## 6. Open questions

- **#94 Visitors:** may visitors (not signed in) start a conversation, like they can fill a basket? My suggestion: **yes**, tied to their browser session like the basket and moved to their account when they sign in; asking for an email address only if they want an answer by email. Offers need an account.
- **#95 Assignment:** notify all available consultants and the first one takes it (my suggestion), or assign automatically by order/priority as in Rails (with a ring sequence)? And what happens outside opening hours – a note "we answer tomorrow" with the conversation waiting?
- **#96 "Cobrowsing":** is "show a page" (the customer opens it with one click) plus the consultant seeing the customer's current page enough?
- **#97 Emails:** email the customer about a reply when they are not online (with a link back into the conversation)? And email consultants about new conversations when nobody is at the desk?
- **#98 Approval:** which offers need a sales manager's approval – e.g. a discount above 10 % on an item or the total (configurable)? Or none in the first version?
- **#99 Offer PDF:** now (with the offer) or later together with invoices (#17)?
- **#100 Audio/video:** postpone, or a "Video-Termin" link to an external service (e.g. a Jitsi room per conversation)?
- **#101 Feedback:** should customers be able to rate a conversation (thumbs up/down and a comment)?
