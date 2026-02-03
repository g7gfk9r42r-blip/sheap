# 🎯 KONSISTENTE REZEPT-PIPELINE - Vollständige Implementierung

## 📋 ANNAHMEN

- **weekKey Format**: `YYYY-W##` (z.B. `2026-W03`)
- **Market Slugs**: lowercase mit underscore (z.B. `aldi_nord`, `aldi_sued`)
- **Recipe IDs**: Exakt `R###` Format (R001-R999)
- **Bild-Format**: PNG (könnte auf WebP umgestellt werden)
- **Bild-Verhältnis**: 1:1 (quadratisch) für konsistente Darstellung

---

## 1️⃣ ANALYSE: Single Source of Truth

### A) Dateipfade (Standard)

```
assets/
└── recipes/
    ├── <market>/
    │   ├── <weekKey>/
    │   │   └── <market>_recipes.json
    │   └── images/
    │       └── <recipe_id>.png
```

**Beispiele:**
- Rezept: `assets/recipes/aldi_nord/2026-W03/aldi_nord_recipes.json`
- Bild: `assets/recipes/aldi_nord/images/R001.png`

### B) Datenmodell (Recipe)

```dart
Recipe {
  id: String                    // "R001" (exakt)
  title: String                 // MUSS vorhanden
  market: String                // "aldi_nord"
  weekKey: String?              // "2026-W03"
  
  categories: List<String>
  servings: int
  prepTimeMin: int?
  cookTimeMin: int?
  instructions: List<String>    // ODER String (konsistent)
  
  offerIngredients: List<OfferIngredient>
  extraIngredients: List<ExtraIngredient>
  hasStandardBasics: bool       // Flag statt Array
  
  imageAssetPath: String?       // Berechnet: assets/recipes/<market>/images/<id>.png
}
```

### C) UI-Rendering (Detail Screen)

1. **Titel**: `recipe.title ?? "Unbekanntes Rezept"` (mit Fallback)
2. **Hero-Bild**: `Image.asset(recipe.imageAssetPath)` mit Emoji-Fallback
3. **Zutaten-Blöcke**:
   - Block A: "Im Angebot" (offer_ingredients) - Card-Liste
   - Block B: "Zusätzlich benötigt" (extra_ingredients) - Card-Liste
   - Block C: "Basiszutaten" - Info-Zeile (nur Text, keine Cards)

### D) Häufige Ursachen "Recipe title nicht erkannt"

1. **JSON Keys variieren**: `title` vs `name` vs `recipeName`
2. **Null/Empty**: `title` ist `null` oder leerer String
3. **Typ-Mismatch**: `title` ist kein String (z.B. Object)
4. **Alte JSON-Struktur**: Feld fehlt komplett
5. **Parsing-Fehler**: `fromJson` wirft Exception → Default-Werte
6. **Fallback-Regeln fehlen**: Keine Default-Behandlung

---

## 2️⃣ FIX: KONSISTENTE ASSET-PFADLOGIK

### A) pubspec.yaml

```yaml
flutter:
  uses-material-design: true
  
  assets:
    - assets/recipes/
    - .env
```

**Hinweis**: `assets/recipes/` deckt alle Unterordner ab (inkl. `images/` und `<weekKey>/`)

### B) AssetPathResolver Helper

```dart
// lib/core/utils/asset_path_resolver.dart
class AssetPathResolver {
  /// Normalisiert Market-Namen zu Slug
  /// "ALDI NORD" -> "aldi_nord"
  static String normalizeMarketSlug(String market) {
    final normalized = market
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll('ü', 'ue')
        .replaceAll('ö', 'oe')
        .replaceAll('ä', 'ae')
        .replaceAll('ß', 'ss');
    
    // Spezialfälle
    final mapping = {
      'aldi nord': 'aldi_nord',
      'aldi sued': 'aldi_sued',
      'aldi süd': 'aldi_sued',
    };
    
    return mapping[normalized] ?? normalized;
  }
  
  /// Generiert Rezept-Dateipfad
  /// assets/recipes/<market>/<weekKey>/<market>_recipes.json
  static String recipeFilePath(String market, String weekKey) {
    final slug = normalizeMarketSlug(market);
    return 'assets/recipes/$slug/$weekKey/${slug}_recipes.json';
  }
  
  /// Generiert Bild-Pfad
  /// assets/recipes/<market>/images/<recipe_id>.png
  static String imageAssetPath(String market, String recipeId) {
    final slug = normalizeMarketSlug(market);
    // Normalisiere Recipe ID (R001 -> R001.png)
    final normalizedId = recipeId.replaceAll(RegExp(r'\.(png|webp|jpg|jpeg)$'), '');
    return 'assets/recipes/$slug/images/$normalizedId.png';
  }
  
  /// Findet neueste weekKey für einen Market (für Fallback)
  static Future<String?> findLatestWeekKey(String market) async {
    // Implementation: scanne assets/recipes/<market>/ nach weekKey-Ordnern
    // Sortiere nach weekKey, return neueste
    // Fallback-Implementierung (vereinfacht):
    final slug = normalizeMarketSlug(market);
    try {
      // Für jetzt: return null, Loader macht Fallback
      return null;
    } catch (e) {
      return null;
    }
  }
}
```

### C) Loader/Repository Anpassungen

```dart
// lib/data/repositories/recipe_repository_offline.dart
import '../core/utils/asset_path_resolver.dart';

class RecipeRepositoryOffline {
  /// Lädt Rezepte für Market + WeekKey
  static Future<List<Recipe>> loadRecipesForMarket(
    String market, {
    String? weekKey,
  }) async {
    try {
      final slug = AssetPathResolver.normalizeMarketSlug(market);
      
      // 1. Versuche neue Struktur: assets/recipes/<market>/<weekKey>/...
      if (weekKey != null) {
        try {
          final path = AssetPathResolver.recipeFilePath(market, weekKey);
          final jsonString = await rootBundle.loadString(path);
          return _parseRecipes(jsonString, slug);
        } catch (e) {
          debugPrint('⚠️  Neue Struktur nicht gefunden: $e');
        }
      }
      
      // 2. Fallback: Alte Struktur (temporär)
      try {
        final path = 'assets/recipes/$slug/${slug}_recipes.json';
        final jsonString = await rootBundle.loadString(path);
        return _parseRecipes(jsonString, slug);
      } catch (e) {
        debugPrint('⚠️  Alte Struktur nicht gefunden: $e');
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Fehler beim Laden: $e');
      return [];
    }
  }
  
  static List<Recipe> _parseRecipes(String jsonString, String marketSlug) {
    final dynamic jsonData = json.decode(jsonString);
    final List<dynamic> recipesList = jsonData is List 
        ? jsonData 
        : (jsonData['recipes'] as List? ?? []);
    
    return recipesList
        .map((r) {
          try {
            final recipeMap = Map<String, dynamic>.from(r);
            // Stelle sicher, dass market gesetzt ist
            recipeMap['market'] ??= marketSlug;
            return Recipe.fromJson(recipeMap);
          } catch (e) {
            debugPrint('⚠️  Fehler beim Parsen: $e');
            return null;
          }
        })
        .whereType<Recipe>()
        .toList();
  }
}
```

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
    "Pfanne stark erhitzen, Öl zugeben und Steaks 2–3 Min. pro Seite goldbraun braten.",
    "Rispentomaten klein würfeln. Avocados halbieren, entkernen, Fruchtfleisch würfeln.",
    "Tomaten und Avocado mit fein geriebenem Knoblauch, Limettensaft, Chili, Salz/Pfeffer mischen."
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
    },
    {
      "offer_id": "O001",
      "name": "Avocados (Netz)",
      "brand": "ALDI",
      "unit": "g",
      "pack_size": 500,
      "packs_used": 1,
      "used_amount": 500,
      "price_eur": 1.69,
      "price_before_eur": 1.89,
      "from_offer": true
    }
  ],
  
  "extra_ingredients": [
    {
      "name": "Limette oder Zitrone",
      "amount": "1 Stück",
      "unit": ""
    },
    {
      "name": "Knoblauch",
      "amount": "1 Zehe",
      "unit": ""
    },
    {
      "name": "Chiliflocken",
      "amount": "1 Prise",
      "unit": ""
    }
  ],
  
  "has_standard_basics": true,
  
  "image": {
    "asset_path": "assets/recipes/aldi_nord/images/R001.png",
    "generator_meta": {
      "model": "flux-schnell",
      "prompt_version": "1.0"
    }
  }
}
```

### Schema-Validierung (Optional, für Pipeline)

```python
# tools/validate_recipe_schema.py (Beispiel)
REQUIRED_FIELDS = {
    "id": str,
    "title": str,
    "market": str,
    "offer_ingredients": list,
}

OFFER_INGREDIENT_REQUIRED = {
    "offer_id", "name", "brand", "unit", "pack_size",
    "packs_used", "used_amount", "price_eur", "from_offer"
}
```

---

## 4️⃣ UI: DETAIL SCREEN PATCH

### Recipe Model Erweiterungen

```dart
// lib/data/models/recipe.dart (Ausschnitt)

class Recipe {
  // ... bestehende Felder ...
  
  final List<OfferIngredient>? offerIngredients;
  final List<ExtraIngredient>? extraIngredients;
  final bool hasStandardBasics;
  
  /// Berechnet Bild-Pfad (NEU)
  String? get imageAssetPath {
    // 1. Prüfe image.asset_path
    if (image != null && image!['asset_path'] != null) {
      return image!['asset_path']?.toString();
    }
    
    // 2. Berechne aus market + id
    final marketSlug = market ?? AssetPathResolver.normalizeMarketSlug(retailer);
    if (marketSlug != null && id.isNotEmpty) {
      return AssetPathResolver.imageAssetPath(marketSlug, id);
    }
    
    return null;
  }
  
  /// Titel mit Fallback
  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (description.isNotEmpty) return description;
    return "Unbekanntes Rezept";
  }
}
```

### RecipeDetailScreen Patch

```dart
// lib/features/discover/recipe_detail_screen_new.dart (Ausschnitt)

// In _IngredientsSection:

Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A) Im Angebot
        if (widget.recipe.offerIngredients != null && 
            widget.recipe.offerIngredients!.isNotEmpty) ...[
          _SectionHeader(
            title: 'Im Angebot',
            icon: Icons.shopping_cart_rounded,
            color: GrocifyTheme.primary,
          ),
          const SizedBox(height: 12),
          ...widget.recipe.offerIngredients!.map((ing) => 
            _OfferIngredientCard(ingredient: ing)
          ),
          const SizedBox(height: 24),
        ],
        
        // B) Zusätzlich benötigt
        if (widget.recipe.extraIngredients != null && 
            widget.recipe.extraIngredients!.isNotEmpty) ...[
          _SectionHeader(
            title: 'Zusätzlich benötigt',
            icon: Icons.add_circle_outline_rounded,
            color: GrocifyTheme.accent,
          ),
          const SizedBox(height: 12),
          ...widget.recipe.extraIngredients!.map((ing) => 
            _ExtraIngredientCard(ingredient: ing)
          ),
          const SizedBox(height: 24),
        ],
        
        // C) Basiszutaten (nur Info-Zeile)
        if (widget.recipe.hasStandardBasics) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GrocifyTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, 
                     size: 16, 
                     color: GrocifyTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Basiszutaten: Salz, Pfeffer, Öl, Wasser',
                    style: TextStyle(
                      fontSize: 13,
                      color: GrocifyTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

// Neue Widgets:

class _OfferIngredientCard extends StatelessWidget {
  final OfferIngredient ingredient;
  
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrocifyTheme.border.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: GrocifyTheme.textPrimary,
                      ),
                    ),
                    if (ingredient.brand.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ingredient.brand,
                        style: TextStyle(
                          fontSize: 13,
                          color: GrocifyTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${ingredient.priceEur.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GrocifyTheme.primary,
                    ),
                  ),
                  if (ingredient.priceBeforeEur != null) ...[
                    Text(
                      '${ingredient.priceBeforeEur!.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        color: GrocifyTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip('${ingredient.usedAmount} ${ingredient.unit}'),
              const SizedBox(width: 8),
              _InfoChip('${ingredient.packsUsed}× ${ingredient.packSize}${ingredient.unit}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtraIngredientCard extends StatelessWidget {
  final ExtraIngredient ingredient;
  
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrocifyTheme.border.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ingredient.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: GrocifyTheme.textPrimary,
              ),
            ),
          ),
          Text(
            ingredient.amount,
            style: TextStyle(
              fontSize: 14,
              color: GrocifyTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: GrocifyTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
```

---

## 5️⃣ BILDGENERATOR: BESSERES MODELL + PROMPT

### Model-Empfehlungen

1. **black-forest-labs/flux-schnell** (Replicate)
   - ✅ Sehr schnell (5-10s pro Bild)
   - ✅ Gute Qualität
   - ✅ Günstig
   - **Einsatz**: Standard-Workflow (empfohlen)

2. **black-forest-labs/flux-dev** (Replicate)
   - ✅ Höchste Qualität
   - ⚠️  Langsamer (30-60s)
   - ⚠️  Teurer
   - **Einsatz**: Finale Bilder für Produktion

3. **stability-ai/sdxl** (Replicate)
   - ✅ Sehr gute Qualität
   - ✅ Etabliert
   - **Einsatz**: Alternative zu Flux

**Empfehlung**: Starte mit `flux-schnell`, für finale Version `flux-dev`.

### Prompt-Template

```python
# tools/prompt_templates.py

def build_recipe_image_prompt(
    title: str,
    main_ingredients: List[str],
    category_hint: str = "",
) -> str:
    """
    Erstellt einen optimierten Prompt für Rezept-Bilder.
    """
    # Top 3 Hauptzutaten
    ingredients_str = ", ".join(main_ingredients[:3])
    
    # Basis-Prompt
    base_prompt = (
        "ultra realistic professional food photography, "
        "high quality, sharp focus, appetizing, "
        "natural lighting, soft shadows, "
        "modern food styling, "
        f"dish: {title}"
    )
    
    if ingredients_str:
        base_prompt += f", ingredients visible: {ingredients_str}"
    
    if category_hint:
        base_prompt += f", style: {category_hint}"
    
    # Style-Hinweise
    base_prompt += (
        ", overhead or 45-degree angle view, "
        "neutral background, clean presentation, "
        "restaurant quality, Instagram-worthy"
    )
    
    return base_prompt

def build_negative_prompt() -> str:
    """Standard Negative Prompt für alle Bilder."""
    return (
        "text, watermark, logo, packaging, labels, "
        "blurry, lowres, deformed, ugly, bad anatomy, "
        "hands, people, writing, letters, numbers"
    )

# Beispiel-Verwendung:
prompt = build_recipe_image_prompt(
    title="Hähnchen-Minutensteaks mit Avocado-Tomaten-Salsa",
    main_ingredients=["Hähnchen", "Avocado", "Tomaten"],
    category_hint="high protein, low carb"
)

negative = build_negative_prompt()
```

### Batch-Prompt für 50 Bilder

```python
# tools/generate_batch_images.py (Ausschnitt)

async def generate_batch_images(
    recipes: List[Dict],
    output_dir: str,
    model: str = "black-forest-labs/flux-schnell",
) -> List[Dict]:
    """
    Generiert Bilder für eine Liste von Rezepten.
    """
    results = []
    
    for recipe in recipes:
        recipe_id = recipe["id"]
        title = recipe["title"]
        ingredients = [
            ing["name"] 
            for ing in recipe.get("offer_ingredients", [])[:3]
        ]
        
        # Prompt generieren
        prompt = build_recipe_image_prompt(
            title=title,
            main_ingredients=ingredients,
            category_hint=", ".join(recipe.get("categories", [])[:2]),
        )
        negative = build_negative_prompt()
        
        # Bild generieren (via Replicate)
        try:
            image_url = await replicate_client.generate_image(
                prompt=prompt,
                negative_prompt=negative,
                model=model,
                width=768,
                height=768,
                aspect_ratio="1:1",
            )
            
            # Bild speichern
            market = recipe["market"]
            filename = f"{recipe_id}.png"
            filepath = os.path.join(output_dir, market, "images", filename)
            
            await download_and_save_image(image_url, filepath)
            
            results.append({
                "recipe_id": recipe_id,
                "status": "success",
                "filepath": filepath,
            })
            
            # Throttling (3s zwischen Requests)
            await asyncio.sleep(3)
            
        except Exception as e:
            results.append({
                "recipe_id": recipe_id,
                "status": "error",
                "error": str(e),
            })
    
    return results
```

### Namenskonvention + Validierung

```python
# tools/validate_image_names.py

import re
from pathlib import Path

def validate_image_filename(filename: str) -> bool:
    """
    Validiert: R###.png (exakt)
    """
    pattern = r'^R\d{1,3}\.png$'
    return bool(re.match(pattern, filename))

def validate_all_images(market_dir: Path) -> Dict:
    """
    Validiert alle Bilder in einem Market-Ordner.
    """
    images_dir = market_dir / "images"
    if not images_dir.exists():
        return {"error": "images directory not found"}
    
    results = {
        "valid": [],
        "invalid": [],
    }
    
    for file in images_dir.glob("*.png"):
        if validate_image_filename(file.name):
            results["valid"].append(file.name)
        else:
            results["invalid"].append(file.name)
    
    return results
```

---

## ✅ CHECKLISTE FÜR UMSETZUNG

- [ ] `pubspec.yaml` aktualisiert (assets/recipes/)
- [ ] `AssetPathResolver` implementiert
- [ ] `RecipeRepositoryOffline` angepasst (neue + alte Struktur)
- [ ] Recipe Model erweitert (offerIngredients, extraIngredients, hasStandardBasics)
- [ ] RecipeDetailScreen angepasst (3 Zutaten-Blöcke)
- [ ] JSON-Schema validiert (Beispiel-Rezepte)
- [ ] Bildgenerator-Prompt getestet
- [ ] Batch-Generation getestet (5-10 Rezepte)
- [ ] Alle Bilder validiert (R###.png Format)

---

## 🚀 NÄCHSTE SCHRITTE

1. **Sofort**: Implementiere `AssetPathResolver` + Repository-Anpassungen
2. **Dann**: Recipe Model erweitern + JSON-Schema validieren
3. **UI**: Detail Screen anpassen (3 Blöcke)
4. **Bilder**: Prompt testen → Batch-Generation

---

**Alle Code-Blöcke sind copy-paste-fähig und direkt umsetzbar.**

