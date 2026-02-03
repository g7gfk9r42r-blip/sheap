# Quick Start - Recipe Generator

## Wichtig: Im Projekt-Root ausführen!

Das Script muss **im Projekt-Root** (`roman_app/`) ausgeführt werden, nicht in Unterverzeichnissen.

## Schritt-für-Schritt

### 1. Ins Projekt-Root wechseln

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
```

### 2. .env Datei erstellen (falls nicht vorhanden)

```bash
echo "OPENAI_API_KEY=sk-your-key-here" > .env
```

**Wichtig:** Ersetze `sk-your-key-here` mit deinem echten OpenAI API Key!

### 3. Angebots-JSONs platzieren

Platziere deine Angebots-JSON-Dateien in `assets/data/`:

```bash
# Beispiel-Dateien:
assets/data/angebote_lidl_2025-W49.json
assets/data/angebote_rewe_2025-W49.json
assets/data/angebote_edeka_2025-W49.json
```

**Dateinamen-Format:**
- `angebote_<supermarket>_<date>.json`
- Unterstützt: `20250101` (YYYYMMDD) oder `2025-W49` (YYYY-Www)

### 4. Script ausführen

```bash
dart run tools/generate_recipes_for_all_supermarkets.dart
```

**Oder mit verbose Output:**

```bash
dart run tools/generate_recipes_for_all_supermarkets.dart --verbose
```

## Erwartete Ausgabe

```
[Grocify] Starting recipe generation for all supermarkets...
[Grocify] ✅ Environment loaded
[Grocify] 📥 Scanning for offer JSON files...
[Grocify] 📊 Found offers for 3 supermarket(s):
[Grocify]    LIDL: 45 offers
[Grocify]    REWE: 52 offers
[Grocify]    EDEKA: 38 offers
[Grocify] 🤖 Generating recipes for LIDL...
[Grocify] ✅ Generated 35 recipes for LIDL
[Grocify] 💾 Saved to assets/recipes/recipes_lidl.json
...
[Grocify] ✅ Recipe generation completed successfully!
```

## Output

Die generierten Rezepte werden in `assets/recipes/` gespeichert:

```
assets/recipes/
├── recipes_lidl.json
├── recipes_rewe.json
└── recipes_edeka.json
```

## Fehlerbehebung

### "Could not find file `tools/...`"
→ Du bist nicht im Projekt-Root. Wechsle mit `cd` ins richtige Verzeichnis.

### "OPENAI_API_KEY not found"
→ Erstelle eine `.env` Datei im Projekt-Root mit deinem API Key.

### "No offer files found"
→ Stelle sicher, dass JSON-Dateien in `assets/data/` liegen und dem Namensschema entsprechen.

### "zsh: command not found: #"
→ Kommentare in der Shell müssen mit `#` am Zeilenanfang stehen. Kopiere die Befehle einzeln.

