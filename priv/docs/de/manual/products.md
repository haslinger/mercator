---
title: Produkte
roles: [productmanager]
order: 50
pages: [admin/products, admin/products/new, admin/products/:id]
---
Unter **Katalog → Produkte** pflegen Sie das Sortiment. Preise und Varianten beschreibt das Kapitel [Varianten und Preise](prices.md), die Maßanfertigung das Kapitel [Konfigurator](configurator.md).

## Die Liste

Suche nach Titel oder Artikelnummer, Filter nach Kategorie (mit Unterkategorien), Status und Produktart. Direkt in der Liste lassen sich Produkte **Aktivieren** oder **Auslaufen lassen**; ein Link führt zum Produkt im Shop.

| Status | Bedeutung |
|---|---|
| Entwurf | in Arbeit, im Shop nicht sichtbar |
| Aktiv | im Shop sichtbar und bestellbar; braucht mindestens eine Variante |
| Ausgelaufen | nicht mehr im Sortiment |

**Neues Produkt** fragt nach Artikelnummer, Titel, Produktart und Steuerklasse und öffnet dann den Produkteditor.

## Produktarten

Jedes Produkt hat mindestens eine Variante; sie trägt Artikelnummer, Einheit, Lager und Preise. Die Produktart bestimmt, was die Kundin oder der Kunde wählt:

| Art | Wahl im Shop | Preis | Lager |
|---|---|---|---|
| einfach | nichts | ein Preis | wird geführt (oder „auf Bestellung“) |
| mit Varianten | eine Variante, z. B. Länge 4 m oder 5 m | je Variante, mit Staffel- und Aktionspreisen | je Variante |
| konfigurierbar | Optionen und Maße, z. B. Holzart und Länge × Breite | vom Konfigurator berechnet | keines, Fertigung auf Bestellung |

Ein Produkt ist entweder eines mit Varianten oder ein konfigurierbares, nicht beides. Wer ein Brett als Lagerware und zusätzlich auf Maß anbieten will, legt zwei Produkte an und verknüpft sie (Reiter **Verknüpfungen**).

**Art ändern** wechselt die Art; die Reiter passen sich sofort an. Dabei geht nichts verloren, nicht Passendes wird nur ausgeblendet. Ein Produkt mit mehreren Varianten lässt sich nicht zu einem einfachen machen, solange die Varianten da sind.

## Der Produkteditor

| Reiter | Inhalt |
|---|---|
| **Allgemein** | Titel, Untertitel und Beschreibungen auf Deutsch und Englisch (Markdown), Highlights (eines pro Zeile), Artikelnummer, Adresse im Shop (aus dem Titel gebildet), Steuerklasse, Versandart, die Kennzeichen **Neu** und **Bestseller**, Kategorien |
| **Preis & Lager** | bei einfachen Produkten: die eine Variante mit ihren Preisen |
| **Varianten & Preise** | bei Produkten mit Varianten, siehe [Varianten und Preise](prices.md) |
| **Artikel & Lieferzeit** | bei konfigurierbaren: Artikelnummer, Einheit, Lieferzeit, ohne Preise |
| **Konfigurator** | bei konfigurierbaren, siehe [Konfigurator](configurator.md) |
| **Bilder** | mehrere Bilder auf einmal hineinziehen; sie werden verkleinert gespeichert. Das erste ist das Hauptbild, Ziehen ändert die Reihenfolge |
| **Eigenschaften** | Werte wie Holzart oder Stärke, gruppiert; sie stehen auf der Produktseite und dienen auf Kategorieseiten als Filter |
| **Verknüpfungen** | Zubehör, Empfehlungen (mit Begründung) und ähnliche Produkte, gefunden über eine Suche; sie erscheinen auf der Produktseite |

## Versand und Steuer

- **Versandart:** Paket, Spedition oder nur Abholung. Ein Speditionsartikel im Warenkorb schließt Paketversand aus, ein Abholartikel erzwingt Abholung.
- **Steuerklasse:** bestimmt den Steuersatz, siehe *Steuerklassen*. Preise werden netto gepflegt und im Shop brutto angezeigt.
