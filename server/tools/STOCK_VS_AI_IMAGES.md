# Stock vs. KI-generierte Bilder

## Übersicht

Dieses System behandelt Rezept-Bilder basierend auf einer Stock-Markierung:

- **Rezepte mit `"stock": true`** → Bilder von Shutterstock laden
- **Rezepte OHNE `"stock"` (oder `"stock": false`)** → Bilder per KI generieren (SDXL)

## Workflow

### 1. Rezepte markieren

Füge in den Rezept-JSONs ein `"stock": true` Feld hinzu für Rezepte, die Stock-Bilder verwenden sollen:

```json
{
  "id": "R001",
  "title": "Skyr-Beeren-Crunch-Bowl",
  "stock": true,  // ← Stock-Markierung
  "retailer": "ALDI Nord",
  ...
}
```

### 2. Bilder generieren/laden

#### Option A: Master-Script (beides)

```bash
# Alle Bilder generieren/laden
python3 server/tools/generate_all_recipe_images.py --retailer aldi_nord

# Nur Stock-Bilder
python3 server/tools/generate_all_recipe_images.py --retailer aldi_nord --stock-only

# Nur KI-Generierung
python3 server/tools/generate_all_recipe_images.py --retailer aldi_nord --ai-only
```

#### Option B: Einzeln

**Stock-Bilder von Shutterstock:**

```bash
# Shutterstock API Token in .env setzen:
# SHUTTERSTOCK_API_KEY=...
# SHUTTERSTOCK_API_SECRET=...

python3 server/tools/fetch_stock_images_shutterstock.py --retailer aldi_nord
```

**KI-Generierung (SDXL):**

```bash
python3 server/tools/generate_recipe_images_sdxl.py --retailer aldi_nord
```

## Image Schema

Das `image` Schema wird automatisch generiert:

### Stock-Rezepte

```json
{
  "image": {
    "source": "shutterstock",
    "shutterstock_url": "https://...",
    "status": "ready"
  }
}
```

### KI-generierte Rezepte

```json
{
  "image": {
    "source": "ai_generated",
    "asset_path": "assets/recipe_images/aldi_nord/2026-W01/R001.webp",
    "status": "ready"
  }
}
```

## Flutter UI

Die UI lädt Bilder automatisch basierend auf `image.source`:

- `source: "shutterstock"` → `Image.network(shutterstock_url)`
- `source: "ai_generated"` oder `"asset"` → `Image.asset(asset_path)`
- `source: "none"` → Emoji-Placeholder

## Shutterstock API Setup

1. **Account erstellen** auf [Shutterstock API](https://www.shutterstock.com/de/developers)
2. **API Key & Secret** erhalten
3. **In `.env` setzen:**

```bash
SHUTTERSTOCK_API_KEY=your_api_key_here
SHUTTERSTOCK_API_SECRET=your_api_secret_here
```

**⚠️ WICHTIG:** 
- Preview-URLs sind nur für Tests
- Für Production müssen Lizenzen gekauft werden!

## Dateien

- `server/tools/fetch_stock_images_shutterstock.py` - Shutterstock API Integration
- `server/tools/generate_recipe_images_sdxl.py` - SDXL KI-Generierung
- `server/tools/generate_all_recipe_images.py` - Master-Script (beides)
- `lib/data/services/supermarket_recipe_repository.dart` - Image Schema Builder
- `lib/core/widgets/molecules/recipe_preview_card.dart` - UI Bild-Loader

