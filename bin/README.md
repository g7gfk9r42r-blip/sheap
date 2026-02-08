# Recipe Generator Tool

Dieses Tool generiert automatisch KI-Rezepte aus Angebots-JSON-Dateien und speichert sie als JSON-Dateien für die Offline-Nutzung in der Flutter-App.

## Voraussetzungen

1. **OpenAI API Key**: Erstelle eine `.env` Datei im Projekt-Root:
   ```
   OPENAI_API_KEY=sk-your-key-here
   ```

2. **Angebots-JSON-Dateien**: Die JSON-Dateien müssen im Server-Verzeichnis liegen:
   ```
   server/media/prospekte/
   ├── rewe/
   │   └── rewe.json
   ├── lidl/
   │   └── lidl.json
   └── edeka/
       └── edeka.json
   ```

## Verwendung

```bash
# Aus dem Projekt-Root
dart run bin/generate_recipes_from_offers.dart
```

## Was passiert?

1. **Lädt Environment-Variablen** aus `.env`
2. **Liest Angebots-JSONs** aus `server/media/prospekte/<retailer>/`
3. **Konvertiert JSON zu Offer-Objekten** (unterstützt verschiedene Formate)
4. **Generiert Rezepte** für jeden Supermarkt mithilfe der OpenAI API
5. **Speichert Rezepte** als JSON in `assets/recipes/recipes_<retailer>.json`

## Unterstützte JSON-Formate

### Format 1: Sections-Format (REWE, EDEKA)
```json
{
  "market": "REWE",
  "sections": [
    {
      "name": "Molkerei & Aufstrich",
      "offers": [
        {
          "title": "Mirée Französische Kräuter",
          "description": "65% Fett i.Tr., je 150-g-Becher",
          "price": "1,11 €"
        }
      ]
    }
  ]
}
```

### Format 2: Standard-Format (direktes Array)
```json
[
  {
    "id": "offer-123",
    "retailer": "LIDL",
    "title": "Produktname",
    "price": 1.99,
    "unit": "kg",
    "validFrom": "2025-01-01T00:00:00Z",
    "validTo": "2025-01-07T23:59:59Z",
    "updatedAt": "2025-01-01T00:00:00Z"
  }
]
```

## Ausgabe

Die generierten Rezepte werden in `assets/recipes/` gespeichert:

```
assets/recipes/
├── recipes_rewe.json
├── recipes_lidl.json
└── recipes_edeka.json
```

Jede Datei enthält ein Array von Recipe-Objekten im Standard-Format:

```json
[
  {
    "id": "recipe-rewe-1-2025-W49",
    "title": "REWE Special Pasta",
    "description": "A delicious pasta dish...",
    "ingredients": ["Pasta", "Tomatoes", "Garlic"],
    "retailer": "REWE",
    "weekKey": "2025-W49",
    "createdAt": "2025-01-01T12:00:00Z"
  }
]
```

## Fehlerbehandlung

- Wenn keine Angebote gefunden werden → Supermarkt wird übersprungen
- Wenn OpenAI API fehlschlägt → Mock-Rezepte werden generiert
- Fehler werden klar geloggt, das Tool bricht nicht ab

## Offline-First Integration

Die generierten JSON-Dateien können direkt in der Flutter-App geladen werden:

```dart
// In der App
final recipesJson = await rootBundle.loadString('assets/recipes/recipes_rewe.json');
final recipes = (jsonDecode(recipesJson) as List)
    .map((r) => Recipe.fromJson(r))
    .toList();
```

## Erweiterte Optionen

Das Tool kann erweitert werden, um:
- Spezifische Supermärkte zu filtern
- Anzahl der Rezepte pro Supermarkt anzupassen
- WeekKey-spezifische Dateien zu generieren
- Batch-Processing für große Datenmengen

