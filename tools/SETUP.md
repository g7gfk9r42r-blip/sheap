# Setup Guide - Recipe Generator

## Problem: "No offers found"

Wenn du diese Fehlermeldung siehst, bedeutet das, dass keine Angebots-JSON-Dateien im `assets/data/` Verzeichnis gefunden wurden.

## Lösung

### Option 1: Automatisches Kopieren (Empfohlen)

Falls du bereits JSON-Dateien im `server/media/prospekte/` Verzeichnis hast, verwende das Helper-Script:

```bash
# Im Projekt-Root
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Kopiere Dateien automatisch
./tools/copy_offers_to_assets.sh
```

Das Script:
- Findet alle JSON-Dateien im `server/media/prospekte/` Verzeichnis
- Kopiert sie nach `assets/data/`
- Benennt sie im korrekten Format um: `angebote_<supermarket>_<date>.json`

### Option 2: Dateien manuell kopieren

Wenn du bereits JSON-Dateien im `server/media/prospekte/` Verzeichnis hast, kannst du sie kopieren:

```bash
# Beispiel: REWE Dateien kopieren
cp server/media/prospekte/rewe/rewe.json assets/data/angebote_rewe_2025-W49.json

# Beispiel: LIDL Dateien kopieren  
cp server/media/prospekte/lidl/lidl.json assets/data/angebote_lidl_2025-W49.json

# Beispiel: EDEKA Dateien kopieren
cp server/media/prospekte/edeka/edeka.json assets/data/angebote_edeka_2025-W49.json
```

### Option 2: Dateien umbenennen

Falls deine Dateien bereits in `assets/data/` sind, aber einen anderen Namen haben, benenne sie um:

```bash
cd assets/data
# Beispiel: Umbenennen
mv deine_datei.json angebote_lidl_2025-W49.json
```

### Option 3: Neue Dateien erstellen

Erstelle neue JSON-Dateien mit dem korrekten Format:

```bash
# Erstelle Beispiel-Datei
cat > assets/data/angebote_lidl_2025-W49.json << 'EOF'
[
  {
    "title": "Hähnchenbrust",
    "price": 4.99,
    "unit": "500g"
  },
  {
    "title": "Reis",
    "price": 1.29,
    "unit": "500g"
  }
]
EOF
```

## Dateinamen-Format

Die Dateien müssen diesem Format entsprechen:

```
angebote_<supermarket>_<date>.json
```

**Supermarket:** lidl, rewe, edeka, aldi, netto, etc. (wird automatisch zu LIDL, REWE, etc. konvertiert)

**Date:** 
- `YYYYMMDD` (z.B. `20250101`)
- `YYYY-Www` (z.B. `2025-W49`)

**Beispiele:**
- ✅ `angebote_lidl_2025-W49.json`
- ✅ `angebote_rewe_20250101.json`
- ✅ `angebote_edeka_2025-W49.json`
- ❌ `lidl.json` (falsches Format)
- ❌ `angebote_lidl.json` (fehlendes Datum)

## JSON-Format der Angebots-Dateien

Die JSON-Dateien können verschiedene Formate haben:

### Format 1: Sections-Format (REWE, EDEKA)
```json
{
  "market": "REWE",
  "sections": [
    {
      "name": "Molkerei",
      "offers": [
        {
          "title": "Milch",
          "description": "je 1 Liter",
          "price": "1,19 €"
        }
      ]
    }
  ]
}
```

### Format 2: Direktes Array (LIDL)
```json
[
  {
    "product": "Hähnchenbrust",
    "price": 4.99,
    "weight": "500g"
  }
]
```

### Format 3: Standard-Format
```json
[
  {
    "id": "offer-123",
    "retailer": "LIDL",
    "title": "Produktname",
    "price": 1.99,
    "unit": "kg"
  }
]
```

Das Tool unterstützt alle diese Formate automatisch!

## Verifizierung

Nach dem Kopieren/Erstellen der Dateien, prüfe:

```bash
# Liste alle Dateien in assets/data/
ls -la assets/data/

# Führe das Tool erneut aus
dart run tools/generate_recipes_from_offers.dart
```

Das Tool sollte jetzt die Dateien finden und verarbeiten.

