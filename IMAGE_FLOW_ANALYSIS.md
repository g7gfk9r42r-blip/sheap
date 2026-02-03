# 🔍 IST-ANALYSE: Bild-Flow und Markt-Fehler

## 1️⃣ Vollständiger Bild-Flow (exakt in Reihenfolge)

### Schritt 1: Image-Pfad wird erzeugt
**Datei:** `lib/features/recipes/data/recipe_loader_from_prospekte.dart`  
**Zeile:** 557-560  
**Code:**
```dart
final imagePath = await RecipeImagePathResolver.resolveImagePath(
  market: market,
  recipeId: recipeId,
);
```
**Feldname:** `imagePath` (lokale Variable)

### Schritt 2: Image-Pfad wird im JSON gespeichert
**Datei:** `lib/features/recipes/data/recipe_loader_from_prospekte.dart`  
**Zeile:** 563-564  
**Code:**
```dart
recipeJson['heroImageUrl'] = imagePath;
recipeJson['image_path'] = imagePath; // Auch für Kompatibilität
```
**Feldnamen:** `heroImageUrl`, `image_path` (beide im JSON)

### Schritt 3: Image-Pfad wird in _recipeFromJson gelesen
**Datei:** `lib/data/models/recipe.dart`  
**Zeile:** 522-536  
**Code:**
```dart
// Prüfe zuerst image_path (für Asset-Pfade) - PRIORITÄT
final imagePath = json['image_path']?.toString();
if (imagePath != null && imagePath.isNotEmpty) {
  if (imagePath.startsWith('assets/')) {
    heroImageUrlValue = imagePath;
  }
}
// Fallback zu heroImageUrl (falls image_path nicht vorhanden)
if (heroImageUrlValue == null || heroImageUrlValue.isEmpty) {
  heroImageUrlValue = json['heroImageUrl']?.toString();
}
```
**Feldname:** `heroImageUrlValue` → wird zu `recipe.heroImageUrl`

### Schritt 4a: Hero verwendet heroImageUrl
**Datei:** `lib/features/recipes/presentation/widgets/recipe_hero_card.dart`  
**Zeile:** 182-183  
**Code:**
```dart
child: recipe.heroImageUrl != null && recipe.heroImageUrl!.isNotEmpty
    ? _buildRecipeImage(recipe.heroImageUrl!)
```
**Feldname:** `recipe.heroImageUrl` ✅ **KORREKT**

### Schritt 4b: Liste verwendet imageSchema (PROBLEM!)
**Datei:** `lib/core/widgets/molecules/recipe_preview_card.dart`  
**Zeile:** 304-311  
**Code:**
```dart
_buildRecipeImage(
  imageUrl: widget.recipe.heroImageUrl,
  imageSchema: widget.recipe.image,  // ← WIRD ZUERST VERWENDET!
  ...
)
```
**Feldname:** `widget.recipe.image` (imageSchema)

**In _buildRecipeImage() Zeile 66-135:**
```dart
// NEU: Verwende image Schema wenn verfügbar
if (imageSchema != null) {
  final assetPath = imageSchema['asset_path']?.toString();
  // ...
  if ((source == 'asset' || source == 'ai_generated') && 
      status == 'ready' && 
      assetPath != null && 
      assetPath.isNotEmpty) {
    return Image.asset(finalPath, ...);  // ← VERWENDET FALSCHEN PFAD!
  }
}
// DEPRECATED: Fallback zu heroImageUrl (Zeile 138)
if (imageUrl == null || imageUrl.isEmpty) {
  return _EmojiPlaceholder(...);
}
```

---

## 2️⃣ Vergleich Hero vs. Liste

**Das Bild erscheint im Hero, weil:**
- Hero verwendet `recipe.heroImageUrl` direkt (Zeile 182-183)
- `heroImageUrl` enthält korrekten Pfad: `assets/images/aldi_sued_R001.png`
- `_buildRecipeImage()` prüft `startsWith('assets/')` und verwendet `Image.asset()`

**Es erscheint nicht in der Liste, weil:**
- Liste verwendet `RecipePreviewCard` → `_buildRecipeImage()` mit `imageSchema` Parameter
- `imageSchema` wird in `recipe_loader_from_prospekte.dart` Zeile 570 erstellt:
  ```dart
  recipeJson['image'] = SupermarketRecipeRepository.buildImageSchema(recipeJson, market);
  ```
- `buildImageSchema()` erstellt falschen Pfad: `assets/recipe_images/aldi_sued/R001.webp` (Zeile 298)
- Tatsächliche Bilder liegen unter: `assets/images/aldi_sued_R001.png`
- `_buildRecipeImage()` verwendet `imageSchema['asset_path']` (Zeile 105) → falscher Pfad
- Fallback zu `heroImageUrl` greift NICHT, weil `imageSchema != null` (Zeile 66)

---

## 3️⃣ _recipeFromJson Prüfung

**Wird heroImageUrl korrekt aus dem JSON gelesen?**
✅ JA - Zeile 522-536 liest `image_path` (Priorität) oder `heroImageUrl` (Fallback)

**Wird heroImageUrl überschrieben?**
❌ NEIN - `heroImageUrlValue` wird nur gesetzt, nicht überschrieben

**Wird heroImageUrl ignoriert?**
⚠️ TEILWEISE - In `RecipePreviewCard._buildRecipeImage()` wird `imageSchema` zuerst geprüft (Zeile 66), `heroImageUrl` wird nur verwendet wenn `imageSchema == null` oder leer (Zeile 138)

**Konkurrierende Felder:**
- `image_path` (Zeile 522) - wird bevorzugt
- `heroImageUrl` (Zeile 535) - Fallback
- `image` (imageSchema) - wird in Liste verwendet statt heroImageUrl

**Exakte Ursache:**
- `buildImageSchema()` erstellt `asset_path: 'assets/recipe_images/$retailerSlug/$recipeId.webp'` (Zeile 298)
- Tatsächliche Bilder: `assets/images/<market>_<recipeId>.png`
- Pfad stimmt nicht überein → Bild wird nicht gefunden

**Minimaler Fix:**
```dart
// In recipe_loader_from_prospekte.dart Zeile 570-573
if (!recipeJson.containsKey('image')) {
  // Setze asset_path im imageSchema auf den bereits aufgelösten heroImageUrl
  final imageSchema = SupermarketRecipeRepository.buildImageSchema(recipeJson, market);
  if (recipeJson['heroImageUrl'] != null && imageSchema['source'] == 'asset') {
    imageSchema['asset_path'] = recipeJson['heroImageUrl']; // ← FIX
  }
  recipeJson['image'] = imageSchema;
}
```

---

## 4️⃣ Markt-Fehler (ALDI_NORD → BIOMARKT)

**Woher kommt recipe.market?**
**Datei:** `lib/features/recipes/data/recipe_loader_from_prospekte.dart`  
**Zeile:** 506  
**Code:**
```dart
recipeJson['market'] = market;  // market kommt aus Ordnername
```
**Quelle:** Ordnername aus `discoverRecipeFiles()` → `assets/prospekte/<market>/`

**Wird market überschrieben?**
❌ NEIN - Zeile 506 setzt market aus Ordnername, wird nicht überschrieben

**Warum ALDI_NORD → BIOMARKT?**
**Datei:** `lib/data/services/supermarket_recipe_repository.dart`  
**Zeile:** 263-267  
**Code:**
```dart
final retailerFromJson = json['retailer']?.toString() ?? '';
final retailerToUse = retailerFromJson.isNotEmpty ? retailerFromJson : supermarket;
final retailerSlug = normalizeRetailerToSlug(retailerToUse);
```
**Problem:**
- `buildImageSchema()` verwendet `retailer` aus JSON (Zeile 263)
- Wenn JSON `"retailer": "BIOMARKT"` enthält, aber `market="aldi_nord"` ist
- Dann wird `asset_path: 'assets/recipe_images/biomarkt/R001.webp'` erstellt
- Aber Bild liegt unter: `assets/images/aldi_nord_R001.png`
- **Lösung:** `buildImageSchema()` sollte `market` Parameter verwenden statt `retailer` aus JSON

**Exakte Ursache:**
- `buildImageSchema()` wird mit `market` Parameter aufgerufen (Zeile 572)
- Aber intern verwendet es `retailer` aus JSON (Zeile 263)
- Wenn JSON falschen retailer hat → falscher Pfad

---

## 5️⃣ Asset-Loading Beweis

**Konkreter Fix für Logging:**

```dart
// In recipe_preview_card.dart Zeile 117-134
return Image.asset(
  finalPath,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    // ✅ BEWEIS: Logge eindeutig ob errorBuilder greift
    if (kDebugMode) {
      debugPrint('❌ RecipePreviewCard Image.asset FAILED:');
      debugPrint('   Path: $finalPath');
      debugPrint('   Error: $error');
      debugPrint('   RecipeId: $recipeId');
      debugPrint('   Market: $retailer');
      debugPrint('   ImageSchema: $imageSchema');
    }
    // ... rest of errorBuilder
  },
);
```

**Zusätzlich in recipe_hero_card.dart Zeile 53-98:**
```dart
return Image.asset(
  imageUrl,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    // ✅ BEWEIS: Logge eindeutig ob errorBuilder greift
    if (kDebugMode) {
      debugPrint('❌ RecipeHeroCard Image.asset FAILED:');
      debugPrint('   Path: $imageUrl');
      debugPrint('   Error: $error');
      debugPrint('   RecipeId: ${recipe.id}');
      debugPrint('   Market: ${recipe.market ?? recipe.retailer}');
    }
    // ... rest of errorBuilder
  },
);
```

