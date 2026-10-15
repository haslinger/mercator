---
title: Konfigurator
roles: [productmanager]
order: 52
---
Konfigurierbare Produkte werden auf Maß gefertigt: Die Kundin oder der Kunde wählt Optionen und gibt Maße ein, der Shop berechnet den Preis sofort. Beispiele aus der Demo sind die Tischplatte nach Maß (pro m²), Konstruktionsholz nach Maß (pro m³) und Latten nach Maß (pro Laufmeter). Eingerichtet wird das im Reiter **Konfigurator** des Produkteditors; das Produkt muss die Art **konfigurierbar** haben (siehe [Produkte](products.md)).

## Die Bausteine

### Preisberechnung

Wonach der Grundpreis gerechnet wird:

| Preisberechnung | Menge pro Stück | braucht die Maße |
|---|---|---|
| pro m³ (Länge × Breite × Stärke) | Länge × Breite × Stärke | Länge, Breite, Stärke |
| pro m² (Länge × Breite) | Länge × Breite | Länge, Breite |
| pro Laufmeter (Länge) | Länge | Länge |
| pro Stück | 1 | keine |

Maße werden in Millimetern eingegeben und für die Rechnung in Meter umgerechnet.

### Optionen

Eine Option ist eine Frage an die Kundin oder den Kunden. Sie ist entweder eine **Auswahl** (z. B. Holzart: Eiche, Nuss, Zirbe) oder eine **Zahl** (z. B. Länge in mm). Jede Option hat eine **Rolle im Preis**:

| Rolle im Preis | Art | Wirkung |
|---|---|---|
| **Grundpreis** | Auswahl | jede Auswahl trägt einen *Grundpreis pro Einheit (netto)*, z. B. Eiche 320 € pro m². Genau eine solche Option pro Produkt |
| **Aufschlag** | Auswahl | jede Auswahl kann einen *Aufschlag in %* (vom Grundbetrag) und/oder einen *Aufschlag pro Stück (netto)* haben, z. B. „gehobelt +15 %“, „Baumkante +90 €“; eine Auswahl ohne Aufschlag kostet nichts extra |
| **Länge**, **Breite**, **Stärke** | Zahl | die Maße für die Preisberechnung, mit *Minimum*, *Maximum*, *Schrittweite* und *Standardwert* |
| **Ohne Preiswirkung** | beides | nur eine Angabe für die Fertigung, z. B. „Bohrungen gewünscht“ |

Jede Option und jede Auswahl hat einen **Schlüssel** (z. B. `species`, `oak`). Er steht in Warenkorb und Bestellung und bildet die Konfigurationsnummer; ändern Sie ihn nach dem Verkaufsstart nicht mehr. Die angezeigten Namen (Deutsch, Englisch) dürfen Sie jederzeit ändern.

Bei Auswahlen ist eine die **Standardauswahl**, bei Zahlen gibt es einen **Standardwert**: Daraus ergibt sich die **Standardkonfiguration**, mit der die Produktseite startet und deren Preis auf Kategorieseiten als „ab“-Preis steht. Optionen und Auswahlen ordnen Sie durch Ziehen; so erscheinen sie auch im Shop.

### Einstellungen des Produkts

| Einstellung | Wirkung |
|---|---|
| **Maße aufrunden auf (mm)** | Maße werden auf ein Vielfaches aufgerundet, z. B. 10 = ganze Zentimeter: 1795 mm wird zu 1800 mm |
| **Mindestens verrechnete Menge** | die kleinste Menge, die verrechnet wird (in m³, m², lfm oder Stück), für die ganze Position |
| **Mindestbestellwert (netto)** | liegt die Position darunter, wird sie auf diesen Wert angehoben |
| **Zuschnittgebühr pro Stück (netto)** | fester Betrag je Stück für den Zuschnitt |

## So rechnet der Shop

1. Maße aufrunden, Menge pro Stück nach der Preisberechnung bestimmen.
2. Verrechnete Menge = Menge pro Stück × Stückzahl, mindestens die *mindestens verrechnete Menge*.
3. **Grundbetrag** = verrechnete Menge × Grundpreis der gewählten Grundpreis-Auswahl.
4. **Aufschläge in %** beziehen sich auf den Grundbetrag; **Aufschläge pro Stück** und die **Zuschnittgebühr** werden mit der Stückzahl multipliziert.
5. Liegt die Summe unter dem **Mindestbestellwert**, kommt die Differenz als eigene Zeile dazu.
6. Steuer aus der Steuerklasse, alles auf Cent gerundet.

### Beispiel: Tischplatte nach Maß

Preisberechnung pro m², Maße aufrunden auf 10 mm, Mindestbestellwert 150 €. Bestellt wird 1 Stück: Eiche, 1795 × 905 mm, Stärke 40 mm, Kante Facette, weiß geölt.

| Zeile | Rechnung | netto |
|---|---|---|
| Maße | aufgerundet 1800 × 910 mm = 1,638 m² | |
| Grundpreis Eiche | 1,638 m² × 320,00 € | 524,16 € |
| Stärke 40 mm | +25 % vom Grundbetrag | 131,04 € |
| Kante Facette | +35,00 € × 1 Stück | 35,00 € |
| weiß geölt | +8 % vom Grundbetrag | 41,93 € |
| **Summe** | | **732,13 €** |

Dazu 20 % MwSt. (146,43 €), brutto **878,56 €**.

Eine kleine Platte aus Zirbe, 600 × 400 mm (0,24 m² × 280 € = 67,20 €), liegt unter dem Mindestbestellwert: Die Zeile „Mindestbestellwert“ hebt sie um 82,80 € auf 150,00 € netto.

## Was die Kundin oder der Kunde sieht

- **Produktseite:** Auswahlfelder mit ihrer Preiswirkung (z. B. „Eiche – 384,00 €/m²“ brutto, „40 mm (+25 %)“, „Facette (+42,00 € pro Stk.)“), Maßfelder mit dem erlaubten Bereich, die Stückzahl und darunter die Berechnung Zeile für Zeile. Jede Änderung rechnet sofort neu; ungültige Eingaben (zu groß, zu klein, keine Zahl) stehen direkt am Feld.
- **Konfigurationsnummer:** Artikelnummer plus ein kurzer Code, z. B. `BH-TISCHPLATTE-MASS-D2FF1D`. Dieselbe Konfiguration ergibt immer dieselbe Nummer; so findet die Fertigung gleiche Aufträge wieder.
- **Warenkorb:** die Position mit ihrer Konfiguration als Text; der Preis wird bei jeder Anzeige neu berechnet.
- **Bestellung und Auftragsbestätigung:** die Konfiguration als Text auf Deutsch und Englisch, die Konfigurationsnummer und der Preis von damals.
- **Angebote:** Konfigurierte Produkte kommen über **Warenkorb übernehmen** ins Angebot: Die Kundin oder der Kunde konfiguriert im Shop, die Beraterin oder der Berater übernimmt den Warenkorb und passt Preise und Rabatte an.

## Tipps

- Beginnen Sie mit der Grundpreis-Option und den Maßen, dann die Aufschläge. Die Vorschau im Reiter rechnet die Standardkonfiguration und zeigt, was noch fehlt („Noch nicht berechenbar: …“).
- Grenzen Sie Maße mit Minimum und Maximum auf das ein, was die Fertigung kann; der Shop lässt nichts anderes zu.
- Prozentaufschläge wirken nur auf den Grundbetrag, nicht aufeinander: +25 % und +8 % sind zusammen +33 % des Grundbetrags.
