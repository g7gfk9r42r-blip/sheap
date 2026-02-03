# Rezept-Bild Generierung

Vollautomatische KI-Bildpipeline für Rezeptbilder mit OpenAI Images API.

## Übersicht

Das Script `generate_recipe_images.py` generiert hochwertige Food-Fotos für Rezepte, speichert sie lokal als WEBP-Dateien und erweitert die Rezept-JSON-Dateien um Bild-Metadaten.

## Features

- ✅ **OpenAI Images API Integration** (DALL-E 3)
- ✅ **Lokale Speicherung** als WEBP (optimiert, kleinere Dateigröße)
- ✅ **Robuste Fehlerbehandlung** mit Retries und Exponential Backoff
- ✅ **Idempotenz**: Überspringt bereits generierte Bilder
- ✅ **Marken-Entfernung**: Automatische Bereinigung von Marken/Logos in Prompts
- ✅ **Batch-Verarbeitung**: Verarbeitet alle Rezept-Dateien automatisch

## Installation

### Dependencies

```bash
pip install openai pillow requests
```

### API Key Setup

Der OpenAI API Key muss in der Umgebung verfügbar sein:

```bash
export OPENAI_API_KEY='your-api-key'
```

Oder in einer `.env` Datei im `server/` Verzeichnis:

```
OPENAI_API_KEY=your-api-key
```

Das Script lädt automatisch `.env` Dateien.

## Verwendung

### Basis-Usage

```bash
python3 server/tools/generate_recipe_images.py \
  --input-dir server/assets/recipes \
  --output-dir server/media/recipe_images \
  --out-json-dir server/media/recipes_with_images
```

### Mit Limit (z.B. für Testing)

```bash
python3 server/tools/generate_recipe_images.py \
  --input-dir server/assets/recipes \
  --limit 5  # Nur 5 Rezepte pro Datei
```

### Parameter

- `--input-dir`: Verzeichnis mit Rezept-JSON-Dateien (Pattern: `recipes_*.json`)
- `--output-dir`: Verzeichnis für generierte Bilder (Format: `<weekKey>/<recipeId>.webp`)
- `--out-json-dir`: Verzeichnis für erweiterte JSON-Dateien
- `--limit`: Max Anzahl Rezepte pro Datei (0 = unlimited)

## Output-Struktur

### Bilder

Bilder werden gespeichert unter:
```
server/media/recipe_images/
  └── <weekKey>/
      ├── <recipeId>.webp
      └── ...
```

### JSON-Dateien

Jede Input-Datei erhält eine entsprechende Output-Datei:
```
server/media/recipes_with_images/
  └── recipes_with_images_<supermarket>_<weekKey>.json
```

### Erweiterte Rezept-Felder

Jedes Rezept-Objekt wird erweitert um:

```json
{
  "id": "R001",
  "name": "Kartoffelgratin",
  // ... bestehende Felder ...
  "image_path": "server/media/recipe_images/2025-12-29/R001.webp",
  "image_prompt": "Ultra realistic food photography of...",
  "image_provider": "openai",
  "image_status": "generated",  // "generated" | "skipped" | "failed"
  "image_error": null  // Nur wenn failed
}
```

## Prompt-Builder

Das Script entfernt automatisch:
- Supermarkt-Namen (ALDI, REWE, LIDL, etc.)
- Marken (MILSANI, LEERDAMMER, etc.)
- Mengenangaben und Sonderzeichen
- Verpackungs-Hinweise

Und generiert generische, markenfreie Prompts für Food-Fotografie.

## Error Handling

- **Retries**: Max 3 Versuche pro Rezept mit Exponential Backoff (1s, 2s, 4s)
- **Fehler-Isolation**: Ein fehlgeschlagenes Rezept stoppt nicht die gesamte Pipeline
- **Status-Tracking**: Jedes Rezept hat `image_status` (generated/skipped/failed)
- **Idempotenz**: Bereits existierende Bilder werden übersprungen

## Performance

- **Rate Limiting**: 0.5s Pause zwischen Requests
- **Batch-Verarbeitung**: Alle Dateien werden nacheinander verarbeitet
- **Progress-Logging**: Detaillierter Fortschritt pro Rezept und Datei

## Beispiel-Output

```
======================================================================
🍽️  REZEPT-BILD GENERIERUNG (OpenAI Images API)
======================================================================
📁 Input: server/assets/recipes
🖼️  Bilder: server/media/recipe_images
📄 JSON Output: server/media/recipes_with_images
📊 Dateien: 10

======================================================================
📝 Verarbeite: recipes_aldi_sued.json
======================================================================
  📊 30 Rezepte gefunden
  📅 Week Key: unknown
  🏪 Supermarkt: aldi_sued

  ✅ [1/30] aldi_sued-1: Generiert → aldi_sued-1.webp
  ✅ [2/30] aldi_sued-2: Generiert → aldi_sued-2.webp
  ...

  📊 Summary:
     ✅ Generiert: 30
     ⏭️  Übersprungen: 0
     ❌ Fehlgeschlagen: 0
     ⏱️  Dauer: 245.3s
```

## Kosten-Hinweis

Die OpenAI Images API (DALL-E 3) kostet ca. $0.04 pro Bild (1024x1024, standard quality).

Für 268 Rezepte: ca. $10.72

## Troubleshooting

### "OPENAI_API_KEY nicht gesetzt"

- Prüfe `.env` Datei im `server/` Verzeichnis
- Oder setze Umgebungsvariable: `export OPENAI_API_KEY='...'`

### "openai package nicht installiert"

```bash
pip install openai
```

### "pillow package nicht installiert"

```bash
pip install pillow requests
```

### Rate Limit Errors

Das Script hat bereits Exponential Backoff eingebaut. Bei häufigen Rate Limits:
- Reduziere `--limit` für Tests
- Führe das Script zu verschiedenen Zeiten aus
- Prüfe OpenAI API Quota

## Datei-Struktur

```
server/
  ├── tools/
  │   └── generate_recipe_images.py  # Haupt-Script
  ├── assets/
  │   └── recipes/
  │       ├── recipes_aldi_nord.json
  │       ├── recipes_rewe.json
  │       └── ...
  └── media/
      ├── recipe_images/           # Generierte Bilder
      │   └── <weekKey>/
      │       └── *.webp
      └── recipes_with_images/     # Erweiterte JSON-Dateien
          └── recipes_with_images_*.json
```
