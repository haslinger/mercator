---
title: Varianten und Preise
roles: [productmanager]
order: 51
---
Der Reiter **Varianten & Preise** (bei einfachen Produkten **Preis & Lager**) im Produkteditor; das Kapitel [Produkte](products.md) erklärt die Produktarten.

## Varianten

Eine Variante ist das, was tatsächlich verkauft wird, z. B. „Terrassendiele Lärche 28 × 145 mm, 4 m“. Varianten ordnen Sie durch Ziehen; die erste ist im Shop vorausgewählt.

| Feld | Bedeutung |
|---|---|
| Art.-Nr. | eindeutige Artikelnummer der Variante |
| Name | wie die Variante im Shop heißt, Deutsch und Englisch |
| Einheit | in welcher Einheit verkauft wird (siehe unten) |
| Lagerstand | Menge am Lager; **leer = auf Bestellung** (kein Lager, wird gefertigt oder beschafft) |
| Lieferzeit | Text für die Kundin oder den Kunden, z. B. „2–3 Wochen“ |
| Gewicht (kg) | wird gespeichert; Versandkosten rechnet der Shop derzeit nicht danach |
| Aktiv | inaktive Varianten sind im Shop nicht wählbar |

Beim Bestellen sinkt der Lagerstand, beim Stornieren steigt er wieder. Mehr als vorrätig lässt sich nicht bestellen; Varianten „auf Bestellung“ sind unbegrenzt.

### Einheiten

Stück, Laufmeter (lfm), m², m³, Festmeter (fm), Raummeter (rm), Schüttraummeter (srm), kg, t, Palette und Sack. Bei Stück, Palette und Sack sind nur ganze Mengen möglich, sonst auch Kommazahlen, z. B. 2,5 m³ Brennholz.

## Preise

Jede Variante hat eine oder mehrere Preiszeilen, immer **netto pro Einheit**; der Shop zeigt sie mit der Steuer der Steuerklasse.

| Feld | Bedeutung |
|---|---|
| Nettopreis pro Einheit | der Preis |
| Ab Menge | Staffelpreis: gilt ab dieser Bestellmenge |
| Gültig ab / Gültig bis | zeitlich begrenzter Preis (beides freiwillig) |
| Aktionspreis | ein Sonderpreis; der reguläre Preis erscheint daneben durchgestrichen |

**Welcher Preis gilt:**

1. In Frage kommen die Zeilen, die heute gültig sind und deren „Ab Menge“ höchstens der bestellten Menge entspricht.
2. Unter diesen gewinnt die mit der höchsten „Ab Menge“ (die Staffel); bei Gleichstand die günstigere.
3. Ein Aktionspreis gewinnt nur, wenn er günstiger ist als der reguläre; dann zeigt der Shop ihn mit dem durchgestrichenen regulären Preis und dem Zeichen **Aktion**.

Beispiel: 6,90 € ab 1 Stück, 5,90 € ab 50 Stück. Wer 60 Stück bestellt, zahlt 5,90 € pro Stück. Die Produktseite zeigt die Staffel an.

Auf Kategorieseiten steht bei Produkten mit mehreren Varianten „ab“ und der günstigste Preis.

## Was beim Ändern gilt

- **Warenkorb:** rechnet immer mit den aktuellen Preisen; eine Preisänderung wirkt sofort.
- **Bestellungen** behalten Texte, Preise und Steuer von damals.
- **Angebote** behalten ihre Preise; **Kopieren** übernimmt die neuen Listenpreise (siehe *Angebote*).
