# Ferienverwaltung (Vacation Management)

Eine moderne iOS-App zur Verwaltung von Schulferien, Feiertagen und Elternurlaub in Deutschland.

## Features

- **Dashboard**: Übersicht aller schulfreien Tage (Ferien + relevante Feiertage) pro Jahr, Anzeige der unbetreuten Tage und Fortschrittsbalken.
- **Ferien**: Nach Jahr gruppierte Liste aller Schulferien und relevanten Feiertage im gewählten Bundesland.
- **Urlaub**: Verwaltung der Eltern, deren Urlaubstage, Hinzufügen/Entfernen von Eltern, Anzeige der Urlaubstage pro Elternteil.
- **Einstellungen**: Auswahl des Bundeslands, weitere App-Einstellungen.
- **Push-Benachrichtigungen**: Automatische Erinnerungen 4 Wochen und 1 Woche vor unbetreuten Ferientagen. Über die Einstellungen kann ein Test ausgelöst werden.
- **Import/Export**: Daten können als JSON exportiert und über die Dateien-App oder iCloud importiert werden. Der Import unterstützt security-scoped resources, sodass Dateien aus allen Speicherorten korrekt gelesen werden können.

## Architektur

- SwiftUI App mit MVVM-Pattern
- Datenquellen:
  - openholidaysapi.org für Ferien & Feiertage
  - UserDefaults für lokale Speicherung
- Services: `SchoolHolidayService`, `StorageService`
- State Management über ObservableObject
- Import/Export über `UIDocumentPickerViewController` und Security-Scoped Resource Handling

## Navigation

Die App nutzt eine TabBar mit vier Menüpunkten:
1. **Dashboard** – Übersicht & Auswertung
2. **Ferien** – Ferien- & Feiertagsliste (jahresweise)
3. **Urlaub** – Eltern und Urlaubstage
4. **Einstellungen** – Konfiguration

## Views & Nutzer-Workflow

### Dashboard

- Übersicht über die Ferientage des aktuellen und nächsten Jahres
- Für jedes Jahr:
  - **Gesamtzahl Ferientage** (groß)
  - **Kreisdiagramm**: Verhältnis betreuter/unbetreuter Ferientage
  - **Große Prozentzahl**: Betreuungsquote
- Direkter Vergleich beider Jahre nebeneinander
- Zeigt auf einen Blick, wie gut die Betreuung organisiert ist

### Ferien

- Nach Jahr gruppierte Liste aller Schulferien und relevanten Feiertage
- Bundesland-spezifisch, automatisch aktualisiert
- Feiertage, die in Ferien fallen, werden nicht doppelt gezählt

### Urlaub (Eltern)

- Verwaltung aller Eltern/Betreuer
- Urlaubstage pro Elternteil erfassen und anzeigen
- Übersicht, wie viele Tage pro Elternteil betreut werden
- Urlaubstage können hinzugefügt und entfernt werden

### Einstellungen

- Auswahl des Bundeslands (wirkt sich auf Ferien/Feiertage aus)
- Weitere App-Einstellungen (z.B. Daten zurücksetzen)

## Kalenderübersicht-Button

- Der Button "Kalenderübersicht" befindet sich ausschließlich auf der Startseite (Home Tab).
- Er erscheint nur, wenn der Home Tab aktiv ist, und öffnet eine Jahresübersicht aller Monate im Kalender.
- Auf allen anderen Seiten/Tabs ist dieser Button **nicht sichtbar**.

## Weitere UI-Änderungen

- Die Kalenderübersicht zeigt das Jahr 2025 als Standard und erlaubt die Auswahl zwischen 2024, 2025 und 2026.
- Die Ansicht ist farblich codiert für Ferien ohne/mit Betreuung und reguläre Betreuungstage.
- Einstellungen und andere Views enthalten keinen Kalenderübersicht-Button mehr.

## Nutzer-Workflow

1. **Bundesland wählen** (im Tab „Einstellungen“)
2. **Eltern/Betreuer anlegen** (im Tab „Urlaub“)
3. **Urlaubstage für Eltern erfassen** (Datum auswählen, speichern)
4. **Dashboard nutzen**:
   - Überblick über die Betreuungssituation für aktuelles und nächstes Jahr
   - Unbetreute Tage erkennen und ggf. weitere Urlaube planen
5. **Ferien/Feiertage einsehen** (im Tab „Ferien“)
6. **Push-Benachrichtigungen testen** (im Tab „Einstellungen“ unter „Benachrichtigungen“ mit dem Test-Button)

Alle Daten werden lokal gespeichert. Ferien & Feiertage werden regelmäßig über die API aktualisiert.

## Technische Hinweise

- **Import/Export**: Beim Import von JSON-Dateien wird nun korrekt `startAccessingSecurityScopedResource()` verwendet, sodass auch Dateien aus iCloud, AppGroup oder anderen Speicherorten gelesen werden können.
- **Fehlerbehandlung**: Fehler beim Import/Export werden im Log ausgegeben.

## Voraussetzungen

- iOS 16 oder neuer
- Internetverbindung zum Laden der Ferien/Feiertage

## Weiterentwicklung

- Schrittweise Wiederherstellung des ursprünglichen DashboardViews mit Tests nach jedem Schritt, um SwiftUI-Binding-Fehler frühzeitig zu erkennen.

## Besonderheiten

- Ferien und Feiertage werden automatisch gefiltert (keine Doppelzählung von Feiertagen, die in Ferien fallen)
- Unbetreute Tage werden pro Jahr berechnet und angezeigt
- Ferien-/Feiertagsliste ist nach Jahr gruppiert
- Moderne, intuitive Navigation

## Installation

Standard SwiftUI-Projekt. Abhängigkeiten siehe `Package.swift` oder Xcode-Projektdateien.

## Datenschutz

Siehe [PRIVACY_POLICY.md](PRIVACY_POLICY.md)

---

*Letzte Aktualisierung: 25.04.2025*
