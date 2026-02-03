# Flutter Code Snippets: Rezeptanzahl & Image Fallback

## 1. Repository: Recipe Count Caching

**File: `lib/data/repositories/recipe_repository.dart`**

```dart
class RecipeRepository {
  // Cache für Recipe-Counts pro Market
  static final Map<String, int> _recipeCountCache = {};
  
  /// Gibt Recipe-Count für einen Market zurück (gecached)
  static Future<int> getRecipeCountForMarket(String retailer) async {
    // Prüfe Cache
    final assetKey = _retailerToAssetKey[retailer.toUpperCase()];
    if (assetKey == null) return 0;
    
    if (_recipeCountCache.containsKey(assetKey)) {
      return _recipeCountCache[assetKey]!;
    }
    
    // Lade Rezepte und zähle
    try {
      final recipes = await loadRecipesFromAssets(retailer);
      final count = recipes.length;
      _recipeCountCache[assetKey] = count;
      return count;
    } catch (e) {
      debugPrint('Error loading recipe count for $retailer: $e');
      return 0;
    }
  }
  
  /// Lädt alle Rezepte und cacht Counts
  static Future<void> preloadRecipeCounts() async {
    for (final retailer in _retailerToAssetKey.keys) {
      await getRecipeCountForMarket(retailer);
    }
  }
}
```

## 2. SupermarketCard: Rezeptanzahl anzeigen

**File: `lib/core/widgets/premium/supermarket_card.dart`**

```dart
class SupermarketCard extends StatefulWidget {
  // ... existing fields ...
  
  @override
  State<SupermarketCard> createState() => _SupermarketCardState();
}

class _SupermarketCardState extends State<SupermarketCard> {
  int? _recipeCount;
  bool _isLoadingCount = true;
  
  @override
  void initState() {
    super.initState();
    _loadRecipeCount();
  }
  
  Future<void> _loadRecipeCount() async {
    // Extrahiere Retailer-Name aus Card (kann angepasst werden)
    final retailer = _getRetailerFromName(widget.name);
    if (retailer != null) {
      final count = await RecipeRepository.getRecipeCountForMarket(retailer);
      if (mounted) {
        setState(() {
          _recipeCount = count;
          _isLoadingCount = false;
        });
      }
    } else {
      setState(() {
        _isLoadingCount = false;
      });
    }
  }
  
  String? _getRetailerFromName(String name) {
    // Mapping von Display-Name zu Retailer-Name
    final mapping = {
      'Rewe': 'REWE',
      'Edeka': 'EDEKA',
      'Lidl': 'LIDL',
      'Aldi Nord': 'ALDI NORD',
      'Aldi Süd': 'ALDI SÜD',
      // ... weitere Mappings
    };
    return mapping[name];
  }
  
  @override
  Widget build(BuildContext context) {
    // ... existing code ...
    
    // Ersetze recipeCount Badge:
    Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GrocifyTheme.spaceLG,
        vertical: GrocifyTheme.spaceMD,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusRound),
      ),
      child: _isLoadingCount
          ? SizedBox(
              width: 60,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              _recipeCount != null 
                  ? '$_recipeCount Rezepte' 
                  : '${widget.recipeCount} Rezepte',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  }
}
```

## 3. Image Loading: Robuster Fallback

**File: `lib/core/widgets/molecules/recipe_preview_card.dart`**

```dart
import '../../assets/asset_index_service.dart';

Widget _buildRecipeImage({
  required String? imageUrl,
  required String recipeTitle,
  required double imageHeight,
  Map<String, dynamic>? imageSchema,
  String? retailer,
  String? recipeId,
}) {
  // ... existing Shutterstock logic ...
  
  // Asset Loading mit robustem Fallback
  if ((source == 'asset' || source == 'ai_generated') && 
      status == 'ready' && 
      assetPath != null && 
      assetPath.isNotEmpty) {
    
    final assetIndexService = AssetIndexService.instance;
    final market = retailer ?? '';
    final recipeIdStr = recipeId ?? '';
    
    // Bestimme finalen Pfad (mit Fallback)
    String finalPath = assetPath;
    if (market.isNotEmpty && recipeIdStr.isNotEmpty) {
      finalPath = assetIndexService.recipeImagePathOrFallback(market, recipeIdStr);
    }
    
    // Lade Asset mit mehreren Fallback-Ebenen
    return Image.asset(
      finalPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback 1: Versuche Placeholder
        return Image.asset(
          'assets/recipe_images/_fallback/placeholder.webp',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback 2: Emoji Placeholder (NIEMALS Exception!)
            return _EmojiPlaceholder(
              emoji: _getEmojiForRecipe(recipeTitle),
              size: imageHeight * 0.5,
            );
          },
        );
      },
      // Cache-Policy für bessere Performance
      cacheWidth: (imageHeight * 2).toInt(),
      cacheHeight: imageHeight.toInt(),
    );
  }
  
  // ... rest of existing code ...
}
```

## 4. Home Screen: Preload Recipe Counts

**File: `lib/features/home/home_screen.dart`**

```dart
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _preloadRecipeCounts();
  }
  
  Future<void> _preloadRecipeCounts() async {
    // Preload Recipe Counts im Hintergrund
    RecipeRepository.preloadRecipeCounts().catchError((e) {
      debugPrint('Error preloading recipe counts: $e');
    });
  }
  
  // ... rest of existing code ...
}
```

## 5. AssetIndexService: Erweitert für Recipe Counts

**File: `lib/core/assets/asset_index_service.dart`**

```dart
class AssetIndexService {
  // ... existing code ...
  
  /// Gibt Recipe-Count für einen Market zurück
  int getRecipeCount(String market) {
    if (_index == null) return 0;
    final marketSlug = _normalizeMarketSlug(market);
    
    final recipes = _index!['recipes'] as Map<String, dynamic>?;
    if (recipes == null) return 0;
    
    final marketData = recipes[marketSlug] as Map<String, dynamic>?;
    if (marketData == null) return 0;
    
    return marketData['count'] as int? ?? 0;
  }
  
  /// Gibt alle Recipe-Counts zurück
  Map<String, int> getAllRecipeCounts() {
    if (_index == null) return {};
    
    final recipes = _index!['recipes'] as Map<String, dynamic>?;
    if (recipes == null) return {};
    
    final counts = <String, int>{};
    for (final entry in recipes.entries) {
      final market = entry.key;
      final data = entry.value as Map<String, dynamic>?;
      counts[market] = data?['count'] as int? ?? 0;
    }
    
    return counts;
  }
}
```

