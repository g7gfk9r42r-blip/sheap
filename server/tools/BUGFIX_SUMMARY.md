# Bugfix Summary: Supermarkt-Naming Fix

## Problem
Bei `recipes_norma.json` wurden fälschlicherweise Bildnamen wie "rewe-1.webp" statt "norma-1.webp" verwendet, weil die Recipe-IDs aus dem JSON direkt übernommen wurden, ohne Berücksichtigung des Dateinamens.

## Lösung

### 1. Neue Funktion: `ensure_supermarket_prefix()`
Stellt sicher, dass Recipe-IDs immer mit dem korrekten Supermarkt-Präfix versehen sind, basierend auf dem Dateinamen.

### 2. Safety-Assertion für Supermarkt
- Prüft ob `supermarket` leer oder "unknown" ist
- Loggt Warnung und verwendet "unknown" als Fallback

### 3. Konsistenz-Check für image_path
- Prüft existierende `image_path` Einträge auf Konsistenz
- Warnt wenn Dateiname nicht mit erwartetem Präfix übereinstimmt

### 4. CLI-Flag: `--force-rename`
- Aktiviert aktive Korrektur von inkonsistenten `image_path` Einträgen
- Default: nur warnen

### 5. Recipe-ID wird im Dict aktualisiert
- Wenn ID korrigiert wird, wird sie auch im Recipe-Dict aktualisiert
- Sichert Konsistenz zwischen JSON und Bildnamen

## Test-Ergebnisse

**Vorher:**
```
recipes_norma.json -> "rewe-1", "rewe-2", "rewe-3"
```

**Nachher:**
```
recipes_norma.json -> "norma-1", "norma-2", "norma-3" ✅
```

## Code-Änderungen

### Neue Funktionen
- `ensure_supermarket_prefix(recipe_id, supermarket)` - Normalisiert Recipe-IDs

### Geänderte Funktionen
- `process_recipe()` - Erhält jetzt `supermarket` Parameter explizit
- `process_recipe_file()` - Validiert supermarket, übergibt an `process_recipe()`
- `main()` - Fügt `--force-rename` Flag hinzu

### Safety-Mechanismen
1. Supermarkt wird IMMER aus Dateinamen extrahiert (kein State-Leak)
2. Recipe-IDs werden immer normalisiert bevor verwendet
3. Konsistenz-Checks warnen bei Inkonsistenzen
4. `force_rename` ermöglicht aktive Korrekturen
