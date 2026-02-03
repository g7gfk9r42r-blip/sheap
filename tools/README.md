# Recipe Generator Tool

Automatische Generierung von KI-Rezepten aus Angebots-JSON-Dateien.

## Voraussetzungen

1. **OpenAI API Key**: Erstelle eine `.env` Datei im Projekt-Root:
   ```bash
   echo "OPENAI_API_KEY=sk-your-key-here" > .env
   ```

2. **Angebots-JSON-Dateien**: Platziere JSON-Dateien in `assets/data/` mit dem Format:
   - `angebote_rewe_20250101.json`
   - `angebote_lidl_20250101.json`
   - `angebote_edeka_20250101.json`
   - etc.

## Verwendung

```bash
# Aus dem Projekt-Root
dart run tools/generate_recipes_from_offers.dart
```

## Was passiert?

1. **Lädt Environment-Variablen** aus `.env`
2. **Liest Angebots-JSONs** aus `assets/data/`
3. **Erkennt Supermarkt** aus Dateinamen (z.B. `angebote_rewe_*.json` → REWE)
4. **Generiert 20-50 Rezepte** pro Supermarkt via OpenAI API
5. **Speichert Rezepte** in `assets/recipes/recipes_<supermarket>.json`

## Output-Format

Die generierten Dateien haben exakt dieses Format:

```json
[
  {
    "title": "Hähnchen-Gyros Bowl",
    "ingredients": [
      {"name": "Hähnchenbrust", "amount": "200g"},
      {"name": "Reis", "amount": "150g"},
      {"name": "Paprika", "amount": "1 Stück"}
    ],
    "priceEstimate": 4.79,
    "instructions": "Schritt-für-Schritt Anleitung...",
    "source": "GPT",
    "supermarket": "REWE"
  }
]
```

## Features

- ✅ Automatische Supermarkt-Erkennung aus Dateinamen
- ✅ Batch-Generierung (12 Rezepte pro API-Call)
- ✅ Redundanz-Vermeidung (titelbasierte Filterung)
- ✅ Robuste JSON-Parsing
- ✅ Automatische Verzeichniserstellung
- ✅ Detailliertes Logging

## Optionen

```bash
# Mit verbose Output
dart run tools/generate_recipes_from_offers.dart --verbose
```

## Fehlerbehandlung

- Wenn keine Angebote gefunden werden → Supermarkt wird übersprungen
- Wenn OpenAI API fehlschlägt → Fehler wird geloggt, nächster Supermarkt wird verarbeitet
- Fehler werden klar geloggt, das Tool bricht nicht ab

