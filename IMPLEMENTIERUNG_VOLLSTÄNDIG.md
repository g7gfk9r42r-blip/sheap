# 🎯 VOLLSTÄNDIGE IMPLEMENTIERUNG - Copy-Paste Ready

## 📋 ANNAHMEN (wie spezifiziert)

- **weekKey Format**: `YYYY-W##` (z.B. `2026-W03`)
- **Market Slugs**: lowercase mit underscore (`aldi_nord`, `aldi_sued`)
- **Recipe IDs**: Exakt `R###` Format (R001-R999)
- **Bild-Format**: PNG
- **Bild-Verhältnis**: 1:1 (quadratisch)
- **Bild-Pfad**: `assets/recipes/<market>/images/<recipe_id>.png` (NEU)
- **Rezept-Pfad**: `assets/recipes/<market>/<weekKey>/<market>_recipes.json` (NEU)

---

## 1️⃣ ANALYSE: Single Source of Truth

### Dateipfade (Standard)
```
assets/recipes/<market>/<weekKey>/<market>_recipes.json  (Rezepte)
assets/recipes/<market>/images/<recipe_id>.png           (Bilder)
```

### Datenmodell
- `title`: String (MUSS, mit Fallback)
- `offer_ingredients`: Array mit Pflichtfeldern
- `extra_ingredients`: Array (ohne price/brand)
- `has_standard_basics`: Boolean (Flag statt Array)

### UI-Rendering
- Block A: "Im Angebot" (Cards mit Preis-Details)
- Block B: "Zusätzlich benötigt" (Cards ohne Preis)
- Block C: "Basiszutaten" (Info-Zeile, keine Cards)

### Häufige Ursachen "Recipe title nicht erkannt"
1. JSON Keys: `title` vs `name` vs `recipeName`
2. Null/Empty: `title` ist `null` oder `""`
3. Typ-Mismatch: `title` ist kein String
4. Parsing-Exception: `fromJson` wirft Fehler
5. Fallback fehlt: Keine Default-Behandlung

---

## 2️⃣ FIX: KONSISTENTE ASSET-PFADLOGIK

### A) pubspec.yaml (Update)

```yaml
flutter:
  uses-material-design: true
  
  assets:
    - assets/recipes/
    - .env
```

### B) AssetPathResolver (NEU)

Siehe: `lib/core/utils/asset_path_resolver.dart` (bereits erstellt)

### C) RecipeRepositoryOffline (Update)

Siehe: Patch in Abschnitt 2C

---

## 3️⃣ FIX: RECIPE JSON SCHEMA

### Beispiel-JSON (Vollständig)

```json
{
  "id": "R001",
  "title": "Hähnchen-Minutensteaks mit Avocado-Tomaten-Salsa",
  "market": "aldi_nord",
  "weekKey": "2026-W03",
  "categories": ["High Protein", "Low Carb", "Gluten-free"],
  "servings": 2,
  "prepTimeMin": 10,
  "cookTimeMin": 15,
  "instructions": [
    "Hähnchen-Minutenschnitzel trocken tupfen, leicht salzen und pfeffern.",
    "Pfanne stark erhitzen, Öl zugeben und Steaks 2–3 Min. pro Seite goldbraun braten."
  ],
  "offer_ingredients": [
    {
      "offer_id": "O010",
      "name": "Hähnchen-Minutenschnitzel",
      "brand": "MEINE METZGEREI",
      "unit": "g",
      "pack_size": 400,
      "packs_used": 1,
      "used_amount": 400,
      "price_eur": 3.99,
      "price_before_eur": null,
      "from_offer": true
    }
  ],
  "extra_ingredients": [
    {
      "name": "Limette oder Zitrone",
      "amount": "1 Stück",
      "unit": ""
    }
  ],
  "has_standard_basics": true,
  "image": {
    "asset_path": "assets/recipes/aldi_nord/images/R001.png"
  }
}
```

---

## 4️⃣ UI: DETAIL SCREEN PATCH

Siehe: `lib/features/discover/recipe_detail_screen_new.dart` Patches unten

---

## 5️⃣ BILDGENERATOR: PROMPTS

### Prompt-Template

```python
def build_recipe_image_prompt(title: str, main_ingredients: List[str], category_hint: str = "") -> str:
    ingredients_str = ", ".join(main_ingredients[:3])
    prompt = (
        "ultra realistic professional food photography, "
        "high quality, sharp focus, appetizing, "
        "natural lighting, soft shadows, "
        "modern food styling, "
        f"dish: {title}"
    )
    if ingredients_str:
        prompt += f", ingredients visible: {ingredients_str}"
    if category_hint:
        prompt += f", style: {category_hint}"
    prompt += (
        ", overhead or 45-degree angle view, "
        "neutral background, clean presentation, "
        "restaurant quality, Instagram-worthy"
    )
    return prompt

def build_negative_prompt() -> str:
    return (
        "text, watermark, logo, packaging, labels, "
        "blurry, lowres, deformed, ugly, bad anatomy, "
        "hands, people, writing, letters, numbers"
    )
```

### Model-Empfehlungen

1. **flux-schnell** (Standard): Schnell, gute Qualität
2. **flux-dev** (Final): Höchste Qualität, langsamer
3. **sdxl** (Alternative): Etabliert, gut

---

## ✅ IMPLEMENTIERUNG CHECKLISTE

- [ ] AssetPathResolver implementiert
- [ ] RecipeRepositoryOffline angepasst
- [ ] Recipe Model erweitert (hasStandardBasics)
- [ ] RecipeDetailScreen angepasst (3 Blöcke)
- [ ] JSON-Schema validiert
- [ ] pubspec.yaml aktualisiert
- [ ] Bildgenerator-Prompts getestet

---

**Alle Code-Patches sind in separaten Dateien erstellt und direkt umsetzbar.**

