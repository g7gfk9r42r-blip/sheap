# Changes Summary: Recipe Image Generation Script

## Implementierte Fixes

### A) Stabiler Market-Key pro Datei ✅
- Market wird NUR aus Dateinamen extrahiert: `recipes_<market>.json` -> `<market>` (lowercase, snake_case)
- Lokale Variable `market` pro Datei - kein Leaken zwischen Dateien
- Safety: Wenn Dateiname nicht matcht -> `market="unknown"` + WARNUNG

### B) Stabiler Image-Key pro Rezept ✅
- Deterministischer `image_key = f"{market}-{recipe_id_lower}"`
- Recipe-ID wird NICHT mutiert/korrigiert
- Image-Key wird überall konsistent verwendet:
  - Dateiname: `server/media/recipe_images/{market}/{image_key}.webp`
  - JSON-Feld: `image_path = "server/media/recipe_images/{market}/{image_key}.webp"`

### C) Prompt-Building passend zum Schema ✅
- Nutzt `recipe["title"]` (oder `recipe["name"]` als Fallback)
- Ingredients werden ohne Marken verarbeitet
- `retailer`/`supermarket` als Kontext (nicht als Branding)

### D) Idempotenz richtig ✅
- Wenn WEBP existiert -> skip
- Wenn `image_path` existiert aber Datei fehlt -> regenerate
- Wenn `image_path` auf falschen Ordner zeigt -> WARN + optional mit `--force-rename` verschieben

### E) CLI-Flags ✅
- `--limit N`: Max Anzahl Rezepte pro Datei
- `--force-rename`: Führt Rename/Move wirklich aus
- `--only-market <market>`: Verarbeitet nur eine Datei

## Test-Ergebnisse

### Console-Output:
```
📝 Verarbeite: recipes_norma.json
  🏪 Market: norma
  Image-Keys: norma-rewe-1, norma-rewe-2, norma-rewe-3 ✅
```

### Schema-Verhalten:
- Market aus Dateinamen: `norma` ✅
- Recipe-ID aus JSON: `rewe-1` ✅
- Image-Key: `norma-rewe-1` ✅
- Keine Mutation der Recipe-ID ✅

## Code-Änderungen

### Neue Funktionen:
- `extract_market_from_filename()`: Extrahiert Market aus Dateinamen
- `build_image_key()`: Baut deterministischen Image-Key

### Geänderte Funktionen:
- `process_recipe()`: Nutzt `market` Parameter, baut `image_key`, keine ID-Mutation
- `process_recipe_file()`: Extrahiert `market` lokal, übergibt an `process_recipe()`
- `PromptBuilder.build_prompt()`: Unterstützt sowohl `title` als auch `name`, `retailer`/`supermarket`

### Entfernt:
- `ensure_supermarket_prefix()`: Nicht mehr benötigt (keine ID-Mutation)
- Alle Logik die Recipe-IDs "korrigiert" hat

## Wichtige Prinzipien

1. **Kein State-Leak**: Market wird pro Datei neu extrahiert
2. **Keine Mutation**: Recipe-IDs werden niemals geändert
3. **Determinismus**: Image-Keys sind immer reproduzierbar
4. **Idempotenz**: Existierende Bilder werden nicht neu generiert
5. **Schema-Flexibilität**: Unterstützt sowohl `title`/`name` als auch `retailer`/`supermarket`
