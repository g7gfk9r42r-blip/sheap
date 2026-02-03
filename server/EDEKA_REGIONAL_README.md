# EDEKA Regionale Angebote

## Problem

EDEKA ist in **7 Regionalgesellschaften** unterteilt:
- EDEKA Nord
- EDEKA Minden-Hannover
- EDEKA Rhein-Ruhr
- EDEKA Hessenring
- EDEKA Nordbayern-Sachsen-Thüringen
- EDEKA Südwest
- EDEKA Südbayern

Jede Region hat ihre eigenen Prospekte und Angebote. Auf der offiziellen EDEKA-Website (`edeka.de`) gibt es nur **wenige deutschlandweite Angebote** (ca. 6-12 "SUPERKNÜLLER").

## Lösung

Wir scrapen **direkt von edeka.de/angebote/superknueller**:

1. **Direktes Scraping**: Nutzt Playwright, um die SUPERKNÜLLER-Seite zu scrapen
2. **DOM-Extraktion**: Findet alle Angebote im DOM
3. **Intelligentes Parsing**: Extrahiert Titel, Preis, Rabatt, Einheit, Originalpreis
4. **Deduplizierung**: Entfernt Duplikate automatisch

## Verwendung

```bash
# Testen
npm run test:edeka

# Oder direkt
npm run fetch:edeka
```

## Was wird extrahiert?

- **Titel**: Produktname (z.B. "Rispentomaten")
- **Preis**: Aktionspreis (z.B. 1.49€)
- **Rabatt**: Prozentangabe (z.B. "-50%")
- **Einheit**: Mengenangabe (z.B. "1kg", "200g")
- **Originalpreis**: Falls verfügbar (z.B. "Niedrig. Gesamtpreis: € 0,88")

## Beispiel-Angebote

```
1.49€ - Rispentomaten (1kg)
0.99€ - Arla Buko (-50%, 200g)
1.79€ - Arla Kærgården (-36%, 200g)
1.69€ - Leerdammer Scheiben (-42%, 100g - 160g)
2.22€ - Danone Actimel (-44%, 8x 100g)
13.99€ - Melitta Bella Crema (-30%, 1kg)
0.49€ - Knorr Fix (-59%, 27g - 100g)
1.99€ - Original Wagner Big City Pizza (-43%, 425g)
2.79€ - iglo Schlemmerfilet (-38%, 380g)
2.99€ - Milka Schokolade (-40%, 250g - 300g)
1.49€ - Saft oder Nektar (-25%, 1l)
```

## Vorteile

- ✅ **Direkt von der Quelle**: Offizielle EDEKA-Website
- ✅ **Strukturierte Daten**: DOM-basiert, nicht text-parsing
- ✅ **Zuverlässig**: Weniger abhängig von Drittanbietern
- ✅ **Originalpreise**: Erfasst auch "Niedrig. Gesamtpreis"

## Einschränkungen

- **Nur SUPERKNÜLLER**: Erfasst nur die deutschlandweiten Angebote (ca. 6-12)
- **Keine regionalen Prospekte**: Regionale Angebote werden nicht erfasst
- **DOM-abhängig**: Kann bei Website-Änderungen brechen

## Nächste Schritte (Optional)

1. **Mehrere regionale Prospekte**: Scrapen von mehreren EDEKA-Regionalprospekten
2. **Deduplizierung**: Intelligente Zusammenführung von Angeboten aus verschiedenen Regionen
3. **Region-Metadaten**: Speichern, aus welcher Region ein Angebot stammt
4. **Fallback**: Prospektangebote.de als Fallback, falls direkter Scraper fehlschlägt

