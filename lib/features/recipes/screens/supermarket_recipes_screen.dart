import 'package:flutter/material.dart';
import 'package:roman_app/data/repositories/recipe_repository_offline.dart';
import 'package:roman_app/data/models/recipe.dart';
import '../../discover/recipe_detail_screen_new.dart';
import '../presentation/widgets/recipe_list_card.dart';

/// Screen für Rezepte eines einzelnen Supermarkts
/// Lädt Rezepte aus assets/recipes/<market>/<market>_recipes.json
class SupermarketRecipesScreen extends StatefulWidget {
  final String market; // z.B. "aldi_nord", "rewe"
  final String marketDisplayName; // z.B. "ALDI Nord", "REWE"

  const SupermarketRecipesScreen({
    super.key,
    required this.market,
    required this.marketDisplayName,
  });

  @override
  State<SupermarketRecipesScreen> createState() => _SupermarketRecipesScreenState();
}

class _SupermarketRecipesScreenState extends State<SupermarketRecipesScreen> {
  Future<List<Recipe>>? _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = RecipeRepositoryOffline.loadRecipesForMarket(widget.market);
  }

  Future<void> _reloadRecipes() async {
    setState(() {
      _recipesFuture = RecipeRepositoryOffline.loadRecipesForMarket(widget.market);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(widget.marketDisplayName),
        elevation: 0,
        backgroundColor: colors.surface,
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          // Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Lade Rezepte...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          // Error State
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: colors.error.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fehler beim Laden der Rezepte',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reloadRecipes,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              ),
            );
          }

          final recipes = snapshot.data ?? [];

          // Empty State
          if (recipes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 64,
                      color: colors.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Rezepte verfügbar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Für ${widget.marketDisplayName} sind aktuell\nkeine Rezepte vorhanden.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Zurück'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Success State - Recipe List
          return Column(
            children: [
              // Header mit Rezept-Anzahl
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: colors.outlineVariant.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${recipes.length} Rezept${recipes.length == 1 ? '' : 'e'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Recipe List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RecipeListCard(
                        recipe: recipe,
                        isFavorite: false, // TODO: Implementiere Favoriten-Logik
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailScreenNew(recipe: recipe),
                            ),
                          );
                        },
                        onFavoriteTap: () {
                          // TODO: Implementiere Favoriten-Logik
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

