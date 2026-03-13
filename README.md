# BrannBagFilter

**Originaltaschen-Ersatz mit virtuellen Filtergruppen für World of Warcraft (Retail)**

BrannBagFilter ersetzt sämtliche nativen Taschenfenster durch ein einziges, konfigurierbares Master-Bag. Über selbst erstellte Filterregeln werden Items automatisch in virtuelle Gruppen sortiert – so behältst du immer den Überblick.

![Version](https://img.shields.io/badge/Version-2.0.0-blue)
![WoW](https://img.shields.io/badge/WoW-Retail%2012.0.1+-orange)

---

## Features

### Virtuelle Taschen & Filtergruppen
- Erstelle beliebig viele **virtuelle Gruppen** mit eigenem Namen und Icon
- **15 Filterfelder** kombinierbar mit AND / OR und per-Regel NOT-Invertierung:

| Feld | Beschreibung |
|------|-------------|
| Itemname | Freitext-Suche (Teilstring) |
| Qualität (exakt / min / max) | Poor bis Heirloom (0–7) |
| Item-Level (min / max) | Numerischer Vergleich |
| Ausrüstbar | Ja / Nein |
| Slot | Kopf, Brust, Ring, Schmuckstück, … |
| Typ / Klasse | Freitext auf WoW-Itemtyp |
| Bindung | Seelengebunden / BoE / Kriegsbeute / Nicht gebunden |
| Housing-Item | Möbel & Einrichtung |
| Im Gear-Loadout | Beliebiges Set / bestimmtes Set / kein Set |
| Erweiterung | Classic bis Midnight |
| Ist Item-Upgrade | Vergleich mit angelegtem Gear |
| Bereits gefiltert | Item wurde schon von einer vorherigen Gruppe erfasst |

- **Exklusive Gruppen** – Items erscheinen nur in der exklusiven Gruppe, nicht doppelt
- **„Sonstige"-Sektion** – automatischer Auffangbereich für ungefilterte Items

### Reagenzientasche
- Eigenes Fenster mit **unabhängigen Filtergruppen** für den Reagentbag (Bag 5)
- Aufklappbar über Toggle-Button am Master-Bag

### Verkaufen beim Händler
- Jede Filtergruppe zeigt beim Händler einen **Verkaufen-Button** (Münz-Icon)
- Es werden nur die Items verkauft, die in der jeweiligen Gruppe **tatsächlich sichtbar** sind

### UI & Bedienung
- **Drag & Drop** zum Umsortieren von Filtergruppen
- **Icon-Picker** mit vollständiger Macro-Icon-Bibliothek und Suche
- **Integrierte Suchleiste** – filtert nach Name, Typ und Subtyp
- **Item-Level-Anzeige** auf Ausrüstungsgegenständen mit Qualitätsfarbe
- **Qualitäts-Rahmen** in der jeweiligen Seltenheitsfarbe
- **Vergleichs-Tooltips** beim Hovern über Gear
- **Freie-Plätze-Anzeige** (optional pro physischer Tasche)
- **Sortier-Button** für `C_Container.SortBags()`
- **Spaltenanzahl anpassbar** (1–10) über Resize-Handle
- **Transparenz-Slider** in den Einstellungen
- **Shift+Klick** fügt Itemlink in den Chat ein
- **Verschiebbare Fenster** mit gespeicherter Position

### Keybinding & Slash-Commands
- Eigene Tastenbelegung über WoW-Keybinding-Menü (`BrannBagFilter – Taschen umschalten`)
- Überschreibt native Bag-Keybinds (Rucksack, Tasche 1–4, Reagenzien)
- `/bbf reset` – Einstellungen zurücksetzen und UI neu laden

---

## Installation

1. Lade das AddOn herunter oder klone das Repository:
   ```
   git clone https://github.com/Dakri/BrannBagFilter.git
   ```
2. Kopiere den Ordner `BrannBagFilter` nach:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Starte WoW (neu) und aktiviere das AddOn in der AddOn-Liste.

---

## Konfiguration

Öffne die Einstellungen über das **Zahnrad-Icon** in der Titelleiste des Master-Bags.

**Tab „Einstellungen":**
- Transparenz
- Suchleiste ein/aus
- „Sonstige"-Gruppe ein/aus
- Freie Plätze pro Tasche ein/aus

**Tab „Filter":**
- Filtergruppen erstellen, bearbeiten, löschen und per Drag & Drop sortieren
- Getrennte Listen für Haupttasche und Reagenzientasche
- Regel-Editor mit Spaltenüberschriften und AND/OR/NOT-Logik

---

## Dateistruktur

```
BrannBagFilter/
├── BrannBagFilter.toc   -- AddOn-Manifest
├── Bindings.xml          -- Keybinding-Definition
├── Core.lua              -- Initialisierung, Events, Hilfsfunktionen
├── Filtering.lua         -- Regel-Engine & Item-Matching
├── FilterSettings.lua    -- Einstellungs-UI & Regel-Editor
└── UI.lua                -- Master-Bag-Frame, Rendering, Interaktion
```

---

## Lizenz

Dieses Projekt ist frei nutzbar. Kein offizielles Blizzard-Produkt.
