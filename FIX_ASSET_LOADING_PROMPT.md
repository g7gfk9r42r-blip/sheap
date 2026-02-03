# Fix Asset Loading für Rezept-JSONs - Prompt

## Problem
Die Rezept-JSON-Dateien in `assets/prospekte/` haben unterschiedliche Dateinamen-Patterns:
- **Pattern 1:** `<market>_recipes.json` (z.B. `rewe_recipes.json`, `lidl_recipes.json`)
- **Pattern 2:** `<market>.json` (z.B. `aldi_nord.json`, `lidl.json`)

Einige Märkte haben beide Dateien (z.B. `lidl.json` UND `lidl_recipes.json`).

## Aktuelle Implementierung

### ✅ Bereits implementiert:
1. **Unterstützung für beide Patterns:**
   - `<market>_recipes.json` (bevorzugt)
   - `<market>.json` (Fallback)
   - Wenn beide existieren: `_recipes.json` wird bevorzugt

2. **Unterordner-Unterstützung:**
   - `assets/prospekte/<market>/<market>_recipes.json`
   - `assets/prospekte/<market>/<subfolder>/<market>_recipes.json`
   - Market = Erster Unterordner nach `assets/prospekte/`

3. **Robuste Asset-Manifest-Extraktion:**
   - Unterstützt `Map<String, dynamic>`
   - Unterstützt `Map<String, List<dynamic>>`
   - Unterstützt `List<dynamic>`
   - Normalisiert `assets/assets/` → `assets/`

4. **Umfangreiche Debug-Ausgaben:**
   - Gesamtanzahl Assets
   - Erste 30 Asset-Pfade (Beispiele)
   - Gefundene Recipe JSONs mit Pattern-Typ
   - Pattern-Mismatch-Warnungen

## Code-Location

### Hauptdateien:
- `lib/features/recipes/data/recipe_loader_from_prospekte.dart`
  - `_getAllAssetPaths()` - Extrahiert alle Asset-Pfade
  - `discoverRecipeFiles()` - Findet Recipe JSONs (beide Patterns)
  
- `lib/features/debug/asset_audit.dart`
  - `_getAllAssetPaths()` - Identisch zu RecipeLoader
  - `_findRecipeJsonFiles()` - Identisch zu RecipeLoader

## Unterstützte Strukturen

### ✅ Unterstützt:
```
assets/prospekte/rewe/rewe_recipes.json
assets/prospekte/aldi_nord/aldi_nord.json
assets/prospekte/lidl/lidl.json
assets/prospekte/lidl/lidl_recipes.json (bevorzugt wenn beide existieren)
assets/prospekte/rewe/recipes/rewe_recipes.json (Unterordner)
assets/prospekte/rewe/2024-W01/rewe_recipes.json (Unterordner)
```

## Testen

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Erwarteter Output:
```
📦 Total assets in manifest: 1234
📋 Sample asset paths (first 30): ...
🔍 Scanning 1234 assets for recipe JSONs...
✅ Found recipe file: rewe -> assets/prospekte/rewe/rewe_recipes.json (pattern: _recipes.json)
✅ Found recipe file: aldi_nord -> assets/prospekte/aldi_nord/aldi_nord.json (pattern: <market>.json)
✅ Found recipe file: lidl -> assets/prospekte/lidl/lidl_recipes.json (pattern: _recipes.json)
📄 Total recipe JSON files found: 11

📄 Recipe JSON Files Found: 11
   ✅ rewe: assets/prospekte/rewe/rewe_recipes.json
   ✅ aldi_nord: assets/prospekte/aldi_nord/aldi_nord.json
   ...
```

## Falls weiterhin Probleme

### Problem: Immer noch 0 Recipe JSONs gefunden

**Lösung 1: Prüfe Debug-Output**
- Schaue in Terminal: "Sample asset paths (first 30)"
- Suche nach JSON-Dateien die nicht dem Pattern entsprechen
- Passe Filter entsprechend an

**Lösung 2: Prüfe AssetManifest.json direkt**
```dart
// Temporärer Debug-Code in _getAllAssetPaths():
if (kDebugMode) {
  debugPrint('📋 All asset paths containing "prospekte":');
  for (final path in allPaths) {
    if (path.contains('prospekte')) {
      debugPrint('   - $path');
    }
  }
}
```

**Lösung 3: Erweitere Pattern-Unterstützung**
Falls andere Patterns existieren (z.B. `recipes_<market>.json`):
```dart
// Erweitere in discoverRecipeFiles():
final isRecipesPrefix = filename == 'recipes_$market.json';
if (isRecipesFile || isMarketFile || isRecipesPrefix) {
  // ...
}
```

## Weitere mögliche Anpassungen

### Falls mehrere JSON-Dateien pro Market geladen werden sollen:
```dart
// Sammle alle JSONs pro Market
final jsonFilesByMarket = <String, List<String>>{};
for (final path in allAssetPaths) {
  if (path.startsWith('assets/prospekte/') && path.endsWith('.json')) {
    final parts = path.split('/');
    if (parts.length >= 3) {
      final market = parts[2];
      jsonFilesByMarket.putIfAbsent(market, () => []).add(path);
    }
  }
}
// Dann lade alle oder filtere nach Priorität
```

### Falls Datum-basierte Unterordner (neueste zuerst):
```dart
// Sortiere nach Pfad (neueste zuerst)
final files = jsonFilesByMarket[market]!
    .where((p) => p.contains('${market}_recipes.json') || p.endsWith('${market}.json'))
    .toList()
  ..sort((a, b) => b.compareTo(a)); // Neueste zuerst
```

## Status

✅ Code unterstützt beide Patterns
✅ Code unterstützt Unterordner
✅ Code hat umfangreiche Debug-Ausgaben
✅ Code normalisiert "assets/assets/" Pfade

**Bereit zum Testen!**

