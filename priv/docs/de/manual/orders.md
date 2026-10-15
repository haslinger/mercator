---
title: Bestellungen
roles: [sales, sales_manager]
order: 10
pages: [admin/orders, admin/orders/:number]
---
Unter **Vertrieb → Bestellungen** finden Sie alle Bestellungen, die neuesten zuerst, 25 pro Seite.

## Bestellungen finden

- **Suche:** Bestellnummer, Name, Firma oder E-Mail-Adresse der Kundin oder des Kunden.
- **Filter:** Status, Zeitraum (von – bis) und **Online unbezahlt**: Bestellungen mit Online-Zahlung, die noch nicht bezahlt sind. Sie sind in der Liste mit „unbezahlt“ markiert.

## Eine Bestellung

Die Seite zeigt Kundin oder Kunde, Zahlungsart, die Anmerkung zur Bestellung, Positionen, Adressen und Summen. Oben stehen die **Auftragsbestätigung (PDF)** und **Vorfall melden**, falls mit der Bestellung etwas nicht stimmt.

## Status ändern

Eine Bestellung durchläuft diese Stufen:

| Status | Bedeutung |
|---|---|
| Eingegangen | gerade bestellt, die Ware ist reserviert |
| Bestätigt | geprüft und angenommen |
| Bezahlt | Zahlung eingegangen (bei Online-Zahlung setzt das der Shop selbst) |
| Versendet | unterwegs; bei Abholung heißt diese Stufe **Abholbereit** |
| Abgeschlossen | geliefert bzw. abgeholt |
| Storniert | aufgehoben; die Ware geht zurück ins Lager |

Im Kasten **Status ändern** erscheinen nur die Schritte, die jetzt möglich sind, etwa **Bestätigen**, **Als bezahlt markieren**, **Als versendet markieren** (bei Abholung **Abholbereit melden**), **Abschließen** und **Stornieren**.

- **Notiz:** bleibt intern. Nur der Grund einer Stornierung geht an die Kundin oder den Kunden; ohne Grund lässt sich nicht stornieren.
- **Kunden per E-Mail informieren:** beim Bestätigen, Bezahlen, Versenden bzw. Abholbereit-Melden und Stornieren geht eine E-Mail hinaus. Das Häkchen lässt sich für einen einzelnen Schritt entfernen.
- **Speditionskosten:** wurden die Frachtkosten bei der Bestellung nur geschätzt, verlangt **Bestätigen** die endgültigen Versandkosten; Summe und Steuer werden neu berechnet.
- **Verlauf:** jede Änderung steht mit Zeit, Person und Notiz rechts unten.

## Online-Zahlungen

Bei Bestellungen mit **Online bezahlen** zeigt die Seite alle Zahlungsversuche: Zeit, Status, Zahlungsart, Betrag und die Zahlungsnummer beim Anbieter, mit einem Link in dessen Dashboard. Hat ein Versuch nicht geklappt, kann die Kundin oder der Kunde auf der eigenen Bestellseite **Jetzt bezahlen** wählen.

- **Stornieren einer bezahlten Bestellung:** das Häkchen „Beim Stornieren die Online-Zahlung erstatten“ ist gesetzt; der volle Betrag geht über den Zahlungsanbieter zurück.
- **Später erstatten:** ist eine stornierte Bestellung bezahlt, steht beim Zahlungsversuch **Erstatten**.
- Ob eine Erstattung ausgezahlt wurde, sehen Sie im Dashboard des Zahlungsanbieters (Link beim Zahlungsversuch). Lehnt der Anbieter eine Erstattung ab, entsteht ein Vorfall.
