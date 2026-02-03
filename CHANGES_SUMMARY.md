# ✅ OFFLINE-UMBAU: Zusammenfassung der Änderungen

## 📋 Flutter-Dateien (Diff)

### 1. `lib/main.dart`
```dart
+ import 'core/assets/asset_index_service.dart';
  ...
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await PremiumService.instance.initialize();
+   await AssetIndexService.instance.loadIndex();
    runApp(const GrocifyApp());
  }
```

### 2. `lib/data/services/supermarket_recipe_repository.dart`
```dart
- final assetPath = 'assets/recipe_images/$retailerSlug/$weekKey/$recipeId.webp';
+ final assetPath = 'assets/recipe_images/$retailerSlug/$recipeId.webp';
// WeekKey entfernt!
```

### 3. `lib/core/widgets/molecules/recipe_preview_card.dart`
```dart
+ import '../../assets/asset_index_service.dart';
  ...
  Widget _buildRecipeImage({
    ...
+   String? retailer,
+   String? recipeId,
  }) {
+   // Nutze AssetIndexService für robustes Laden
+   final assetIndexService = AssetIndexService.instance;
+   final finalPath = assetIndexService.recipeImagePathOrFallback(retailer, recipeId);
+   // Fallback zu placeholder.webp wenn nicht vorhanden
  }
```

### 4. `lib/features/discover/widgets/supermarket_recipe_row.dart`
```dart
+ Text('Verfügbare Rezepte: ${recipes.length}', ...)
```

### 5. `lib/features/recipes/presentation/widgets/supermarket_section.dart`
```dart
+ Text('Verfügbare Rezepte: ${recipes.length}', ...)
```

### 6. `lib/features/recipes/presentation/supermarket_recipes_list_screen.dart`
```dart
  AppBar(
-   title: Text(widget.supermarketName),
+   title: Column(
+     children: [
+       Text(widget.supermarketName),
+       Text('Verfügbare Rezepte: ${_recipes.length}'),
+     ],
+   ),
  )
```

## 📋 Neue Dateien

1. `lib/core/assets/asset_index_service.dart` - Asset-Index Service
2. `tools/build_offline_assets.py` - Build-Script (erweitert)
3. `tools/switch_week.sh` - Weekly Switch Script
4. `assets/index/asset_index.json` - Asset-Index (initial)
5. `assets/recipe_images/_fallback/placeholder.webp` - Placeholder

