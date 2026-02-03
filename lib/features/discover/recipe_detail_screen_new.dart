/// Recipe Detail Screen - Grocify Rezept Details
/// Modernized UI mit GrocifyTheme
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/grocify_theme.dart';
import '../../core/widgets/week_day_selector.dart';
import '../../data/models/recipe.dart';
import '../../data/models/recipe_offer.dart';
import '../../data/models/extra_ingredient.dart';
import '../../data/models/offer.dart';
import '../../data/repositories/offer_repository.dart';
import '../../data/services/meal_plan_service.dart';
import '../../data/services/shopping_list_service.dart';
import '../../utils/week.dart';
// Removed: recipe_image_path.dart - verwende jetzt recipe.heroImageUrl direkt

class RecipeDetailScreenNew extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreenNew({super.key, required this.recipe});

  @override
  State<RecipeDetailScreenNew> createState() => _RecipeDetailScreenNewState();
}

class _RecipeDetailScreenNewState extends State<RecipeDetailScreenNew> {
  List<Offer?> _offers = [];
  bool _isFavorite = false;
  int _servings = 2; // Default servings
  // Track which ingredients are selected (checked) - all checked by default
  late Set<int> _selectedIngredientIndices;
  // Track which without-offer ingredients are selected - all checked by default
  late Set<int> _selectedWithoutOfferIndices;

  static bool _isBaseIngredientName(String ingredient) {
    final lower = ingredient.toLowerCase();
    // Basiszutaten: bewusst konservativ (nur klare Basics)
    const keywords = <String>[
      'salz',
      'pfeffer',
      'wasser',
      'öl',
      'oel',
      'olivenöl',
      'olivenoel',
      'butter',
      'zucker',
      'mehl',
    ];
    return keywords.any(lower.contains);
  }

  // Mock data für fehlende Felder
  String get _emoji => _getEmojiForRecipe(widget.recipe.title);
  List<String> get _steps =>
      widget.recipe.steps ?? _getMockSteps(widget.recipe.title);

  String _getEmojiForRecipe(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('pasta') ||
        lower.contains('spaghetti') ||
        lower.contains('nudel')) {
      return '🍝';
    } else if (lower.contains('curry')) {
      return '🍛';
    } else if (lower.contains('salat')) {
      return '🥗';
    } else if (lower.contains('huhn') || lower.contains('chicken')) {
      return '🍗';
    } else if (lower.contains('pizza')) {
      return '🍕';
    } else if (lower.contains('burger')) {
      return '🍔';
    }
    return '🍽️';
  }

  List<String> _getMockSteps(String title) {
    return [
      'Spaghetti nach Packungsanleitung in reichlich Salzwasser kochen.',
      'Speck in kleine Würfel schneiden und in einer Pfanne knusprig anbraten.',
      'Eier mit geriebenem Parmesan verquirlen und mit Salz und Pfeffer würzen.',
      'Nudeln abgießen, dabei etwas Nudelwasser auffangen.',
      'Nudeln mit dem Speck in der Pfanne vermischen und von der Hitze nehmen.',
      'Ei-Käse-Mischung schnell unterrühren, ggf. etwas Nudelwasser zugeben.',
      'Mit frisch gemahlenem schwarzem Pfeffer servieren.',
    ];
  }

  @override
  void initState() {
    super.initState();
    // All ingredients are checked by default
    _selectedIngredientIndices = Set.from(
      List.generate(widget.recipe.ingredients.length, (index) => index),
    );
    _selectedWithoutOfferIndices = Set.from(
      List.generate(widget.recipe.withoutOffers?.length ?? 0, (index) => index),
    );
    
    _loadOffers();
  }

  void _toggleIngredientSelection(int index) {
    setState(() {
      if (_selectedIngredientIndices.contains(index)) {
        _selectedIngredientIndices.remove(index);
      } else {
        _selectedIngredientIndices.add(index);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _toggleWithoutOfferSelection(int index) {
    setState(() {
      if (_selectedWithoutOfferIndices.contains(index)) {
        _selectedWithoutOfferIndices.remove(index);
      } else {
        _selectedWithoutOfferIndices.add(index);
      }
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _loadOffers() async {
    try {
      final weekKey = isoWeekKey(DateTime.now());
      final offers = await OfferRepository.getOffers(
        retailer: widget.recipe.retailer,
        weekKey: weekKey,
      );

      final matchedOffers = <Offer?>[];
      for (final ingredient in widget.recipe.ingredients) {
        try {
          final matchingOffer = offers.firstWhere(
            (offer) =>
                offer.title.toLowerCase().contains(ingredient.toLowerCase()) ||
                ingredient.toLowerCase().contains(offer.title.toLowerCase()),
          );
          matchedOffers.add(matchingOffer);
        } catch (_) {
          matchedOffers.add(null);
        }
      }

      setState(() {
        _offers = matchedOffers;
      });
    } catch (e) {
      // Fehlende Angebote ignorieren
    }
  }

  Future<void> _shareRecipe() async {
    final market = widget.recipe.market?.trim().isNotEmpty == true
        ? widget.recipe.market!.trim()
        : widget.recipe.retailer.trim();

    final lines = <String>[
      widget.recipe.title.trim(),
      'Supermarkt: ${market.toUpperCase()}',
      if (widget.recipe.durationMinutes != null && widget.recipe.durationMinutes! > 0)
        'Dauer: ${widget.recipe.durationMinutes} min',
      if (widget.recipe.servings != null && widget.recipe.servings! > 0)
        'Portionen: ${widget.recipe.servings}',
      '',
      'Zutaten:',
      ...widget.recipe.ingredients.map((s) => '- ${s.trim()}'),
      if ((widget.recipe.withoutOffers ?? const <String>[]).isNotEmpty) ...[
        '',
        'Ohne Angebot:',
        ...(widget.recipe.withoutOffers ?? const <String>[]).map((s) => '- ${s.trim()}'),
      ],
      '',
      'Schritte:',
      ...(_steps.take(12).toList()).asMap().entries.map((e) => '${e.key + 1}. ${e.value.trim()}'),
    ];

    final text = lines.where((s) => s.trim().isNotEmpty).join('\n');

    try {
      await Share.share(text, subject: widget.recipe.title.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Teilen fehlgeschlagen: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addToShoppingList() {
    final shoppingListService = ShoppingListService.instance;

    // Nur ausgewählte (checked) Zutaten zur Einkaufsliste hinzufügen
    final items = <ShoppingListItem>[];
    final market = widget.recipe.market?.trim().isNotEmpty == true
        ? widget.recipe.market!.trim()
        : widget.recipe.retailer.trim();

    for (int i = 0; i < widget.recipe.ingredients.length; i++) {
      // Skip unchecked ingredients
      if (!_selectedIngredientIndices.contains(i)) continue;

      final ingredient = widget.recipe.ingredients[i];
      final offer = i < _offers.length ? _offers[i] : null;

      // Menge extrahieren (falls vorhanden)
      String? amount;
      if (ingredient.contains('(') && ingredient.contains(')')) {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(ingredient);
        if (match != null) {
          amount = match.group(1);
        }
      }

      // Versuche detaillierte Informationen aus offersUsed zu holen
      RecipeOfferUsed? offerUsed;
      if (widget.recipe.offersUsed != null && i < widget.recipe.offersUsed!.length) {
        offerUsed = widget.recipe.offersUsed![i];
      }
      
      final itemName = ingredient.split('(').first.trim();
      final isBase = _isBaseIngredientName(itemName);
      final isFromOffer = offerUsed != null;
      final statusLabel = isFromOffer ? 'Angebot' : (isBase ? 'Basiszutat' : '');

      final item = ShoppingListItem.fromIngredient(
        itemName,
        offerUsed,
          amount: amount,
          offer: offer,
          market: market,
          isBaseIngredient: isBase,
          sourceRecipeId: widget.recipe.id,
          sourceRecipeTitle: widget.recipe.title,
          rawIngredient: ingredient,
          note: statusLabel.isEmpty
              ? 'Quelle: ${widget.recipe.title} (${widget.recipe.id})'
              : 'Quelle: ${widget.recipe.title} (${widget.recipe.id}) • $statusLabel',
      );
      
      // Debug-Logging
      debugPrint('🛒 Adding to shopping list: name=$itemName, brand=${item.brand}, unit=${item.unit}, price=${item.price}, priceBefore=${item.priceBefore}, offerId=${item.offerId}');
      
      items.add(item);
    }

    final wo = widget.recipe.withoutOffers ?? const <String>[];
    for (int i = 0; i < wo.length; i++) {
      if (!_selectedWithoutOfferIndices.contains(i)) continue;

      final ingredient = wo[i];

      // Menge extrahieren (falls vorhanden)
      String? amount;
      if (ingredient.contains('(') && ingredient.contains(')')) {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(ingredient);
        if (match != null) {
          amount = match.group(1);
        }
      }

      final itemName = ingredient.split('(').first.trim();
      final item = ShoppingListItem.fromIngredient(
        itemName,
        null,
        amount: amount,
        offer: null,
        market: market,
        isBaseIngredient: false,
        isWithoutOffer: true,
        sourceRecipeId: widget.recipe.id,
        sourceRecipeTitle: widget.recipe.title,
        rawIngredient: ingredient,
        note: 'Quelle: ${widget.recipe.title} (${widget.recipe.id}) • Ohne Angebot',
      );
      items.add(item);
    }

    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bitte wähle mindestens eine Zutat aus.'),
            backgroundColor: GrocifyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    shoppingListService.addItems(items);
    HapticFeedback.mediumImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${items.length} Zutaten zur Einkaufsliste hinzugefügt',
                ),
              ),
            ],
          ),
          backgroundColor: GrocifyTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _addToMealPlan() async {
    final result = await showWeekDayMealTypeSelector(
      context: context,
      initialDate: DateTime.now(),
    );

    if (result != null &&
        result['date'] != null &&
        result['mealType'] != null) {
      final selectedDate = result['date'] as DateTime;
      final mealType = result['mealType'] as MealType;

      MealPlanService.instance.addRecipeToPlan(
        widget.recipe,
        selectedDate,
        mealType,
      );
      HapticFeedback.mediumImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.recipe.title} zum ${mealType.label} hinzugefügt',
                  ),
                ),
              ],
            ),
            backgroundColor: GrocifyTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: Stack(
        children: [
          // Scrollable Content
          CustomScrollView(
            slivers: [
              // Hero Image Bereich (288px hoch)
              SliverToBoxAdapter(
                child: _HeroSection(
                  recipe: widget.recipe,
                  emoji: _emoji,
                  title: widget.recipe.title,
                  onBack: () => Navigator.pop(context),
                  onShare: _shareRecipe,
                  onHeartTap: () {
                    setState(() {
                      _isFavorite = !_isFavorite;
                    });
                    HapticFeedback.lightImpact();
                  },
                  isFavorite: _isFavorite,
                ),
              ),

              // Content Sections
              SliverPadding(
                padding: const EdgeInsets.only(
                  bottom: 220,
                ), // extra space so steps aren't hidden behind bottom actions
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Premium Header (Title + subtle subtitle + quick facts)
                    _TitleAndFactsSection(recipe: widget.recipe),

                    // Warnings Box (falls vorhanden)
                    if (widget.recipe.warnings != null &&
                        widget.recipe.warnings!.isNotEmpty)
                      _WarningsSection(warnings: widget.recipe.warnings!),

                    // Zutaten (main focus - moved up, description removed)
                    _IngredientsSection(
                      ingredients: widget.recipe.ingredients,
                      withoutOffers: widget.recipe.withoutOffers,
                      offers: _offers,
                      offersUsed: widget.recipe.offersUsed,
                      extraIngredients: widget.recipe.extraIngredients,
                      servings: _servings,
                      selectedIndices: _selectedIngredientIndices,
                      selectedWithoutOfferIndices: _selectedWithoutOfferIndices,
                      onIngredientToggle: _toggleIngredientSelection,
                      onWithoutOfferToggle: _toggleWithoutOfferSelection,
                      onServingsChanged: (newServings) {
                        setState(() {
                          _servings = newServings;
                        });
                      },
                      parentContext: context,
                    ),


                    // Zubereitung (collapsed by default)
                    if (_steps.isNotEmpty)
                      _StepsSection(steps: _steps),

                    // Extra scroll tail so you can comfortably read the last step above the banner
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),

          // Bottom Actions (Fixed)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomActions(
              onAddToMealPlan: _addToMealPlan,
              onAddToShoppingList: _addToShoppingList,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO SECTION
// ============================================================================

class _HeroSection extends StatelessWidget {
  final Recipe recipe;
  final String emoji;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onHeartTap;
  final VoidCallback onShare;
  final bool isFavorite;

  const _HeroSection({
    required this.recipe,
    required this.emoji,
    required this.title,
    required this.onBack,
    required this.onHeartTap,
    required this.onShare,
    required this.isFavorite,
  });

  Widget _buildHeroImage(String emoji) {
    // Pro-level: use the same source as recipe cards (image schema asset_path -> URL when possible).
    final imagePath = recipe.resolvedHeroImageUrlForUi;
    
    if (kDebugMode) {
      debugPrint('🖼️  RecipeDetailScreen Hero Image:');
      debugPrint('   Path: $imagePath');
      debugPrint('   RecipeId: ${recipe.id}');
      debugPrint('   Market: ${recipe.market ?? recipe.retailer}');
    }
    
    final availableNow = recipe.isAvailableNow;
    final validLabel = recipe.validFromUiLabel;

    // Prüfe ob Asset-Pfad
    if (imagePath == null || imagePath.isEmpty) {
      // Kein Bild verfügbar - zeige Gradient mit Emoji
      return Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                GrocifyTheme.primary.withOpacity(0.3),
                GrocifyTheme.accent.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 128),
            ),
          ),
        ),
      );
    }
    
    final isAsset = imagePath.startsWith('assets/');
    
    if (isAsset) {
      return Positioned.fill(
        child: Stack(
          children: [
            Opacity(
              opacity: availableNow ? 1.0 : 0.55,
              child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              debugPrint('❌ RecipeDetailScreen Image.asset FAILED: $imagePath');
            }
            // Fallback zu Emoji wenn Asset nicht existiert
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GrocifyTheme.primary.withOpacity(0.3),
                    GrocifyTheme.accent.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 128),
                ),
              ),
            );
          },
              ),
            ),
            if (!availableNow && validLabel != null)
              Positioned(
                left: 16,
                bottom: 16,
                child: _ValidFromPill(label: validLabel),
              ),
          ],
        ),
      );
    } else if (!isAsset) {
      // Network-URL
      return Positioned.fill(
        child: Stack(
          children: [
            Opacity(
              opacity: availableNow ? 1.0 : 0.55,
              child: Image.network(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          GrocifyTheme.primary.withOpacity(0.3),
                          GrocifyTheme.accent.withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 128)),
                    ),
                  );
                },
              ),
            ),
            if (!availableNow && validLabel != null)
              Positioned(
                left: 16,
                bottom: 16,
                child: _ValidFromPill(label: validLabel),
              ),
          ],
        ),
      );
    } else {
      // Kein Bild verfügbar - zeige Gradient mit Emoji
      return Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                GrocifyTheme.primary.withOpacity(0.3),
                GrocifyTheme.accent.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 128),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketLabel = (recipe.market?.trim().isNotEmpty == true)
        ? recipe.market!.trim().toUpperCase()
        : recipe.retailer.trim().toUpperCase();

    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          // Gradient Background (modernisiert)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GrocifyTheme.primary.withOpacity(0.15),
                  GrocifyTheme.accent.withOpacity(0.1),
                  GrocifyTheme.primary.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Modern Gradient Overlay (für Text-Lesbarkeit - verbessert)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Hero Image oder Emoji Fallback (mit Hero Animation)
          Positioned.fill(
            child: Hero(
              tag: 'recipe-hero-${recipe.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
          _buildHeroImage(emoji),
                    // Extra bottom gradient for “Apple-like” readability
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.00),
                              Colors.black.withOpacity(0.10),
                              Colors.black.withOpacity(0.55),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Navigation Buttons
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), // pt-4 px-5
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    _TopButton(icon: Icons.arrow_back_rounded, onTap: onBack),
                    // Action Buttons (Heart + Share)
                    Row(
                      children: [
                        _TopButton(
                          icon: Icons.favorite_rounded,
                          onTap: onHeartTap,
                          isFavorite: isFavorite,
                        ),
                        const SizedBox(width: 10), // gap-2.5
                        _TopButton(
                          icon: Icons.share_rounded,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onShare();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Market “glass” chip (premium)
          Positioned(
            left: 20,
            bottom: 22,
            child: _GlassChip(
              label: marketLabel,
              icon: Icons.store_rounded,
            ),
          ),

          // Dauer (wenn vorhanden) statt großem Titel im Bild
          if (recipe.durationMinutes != null && recipe.durationMinutes! > 0)
            Positioned(
              right: 20,
              bottom: 22,
              child: _GlassChip(
                label: '${recipe.durationMinutes} min',
                icon: Icons.schedule_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidFromPill extends StatelessWidget {
  final String label;
  const _ValidFromPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isFavorite;

  const _TopButton({
    required this.icon,
    required this.onTap,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final isHeart = icon == Icons.favorite_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 22,
                color: isHeart && isFavorite ? Colors.red : Colors.white,
              ),
            ),
            ),
          ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _GlassChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleAndFactsSection extends StatelessWidget {
  final Recipe recipe;

  const _TitleAndFactsSection({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final market = (recipe.market?.trim().isNotEmpty == true)
        ? recipe.market!.trim().toUpperCase()
        : recipe.retailer.trim().toUpperCase();

    final subtitlePieces = <String>[];
    final cats = recipe.categories ?? const <String>[];
    final tags = recipe.tags ?? const <String>[];
    if (cats.isNotEmpty) {
      subtitlePieces.add(cats.first);
    } else if (tags.isNotEmpty) {
      subtitlePieces.add(tags.first);
    }
    subtitlePieces.add(market);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.title,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: GrocifyTheme.textPrimary,
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitlePieces.join(' • '),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: GrocifyTheme.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),
          _CategoryFactsRow(recipe: recipe),
        ],
      ),
    );
    }
}

class _CategoryFactsRow extends StatelessWidget {
  final Recipe recipe;
  const _CategoryFactsRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    // UI-only: Categories/Tags as the “facts” row (with emojis), per request.
    final candidates = <String>[
      ...(recipe.categories ?? const <String>[]),
      ...(recipe.tags ?? const <String>[]),
    ];

    final unique = <String>[];
    for (final c in candidates) {
      final trimmed = c.trim();
      if (trimmed.isEmpty) continue;
      if (!unique.contains(trimmed)) unique.add(trimmed);
      if (unique.length == 4) break;
    }

    // Add soft-hyphens for nicer German line breaks (no packages).
    String canonicalize(String raw) {
      var s = raw.trim();
      if (s.isEmpty) return s;
      // Normalize common separators to spaces (helps wrapping)
      s = s.replaceAll('_', ' ').replaceAll('-', ' ');
      final lower = s.toLowerCase().trim();

      // Canonical category names (match the filter labels)
      if (lower == 'high protein' || lower.contains('high protein')) return 'High Protein';
      if (lower == 'low carb' || lower.contains('low carb')) return 'Low Carb';
      if (lower == 'vegan') return 'Vegan';
      if (lower == 'vegetarisch' || lower.contains('vegetar')) return 'Vegetarisch';
      if (lower == 'glutenfrei' || lower.contains('gluten')) return 'Glutenfrei';
      if (lower == 'laktosefrei' || lower.contains('laktose')) return 'Laktosefrei';
      if (lower == 'kalorienarm' || lower.contains('kalorien')) return 'Kalorienarm';
      if (lower == 'high calorie' || lower.contains('high calorie')) return 'High Calorie';

      // Fallback: capitalize first letter (requested)
      return s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
    }

    String prettyHyphenate(String raw) {
      final canonical = canonicalize(raw);
      final lower = canonical.toLowerCase();

      if (lower == 'vegetarisch') return 'Vegetar\u00ADisch';
      if (lower == 'vegan') return 'Ve\u00ADgan';
      if (lower == 'high protein') return 'High Pro\u00ADtein';
      if (lower == 'low carb') return 'Low Carb';
      if (lower == 'balanced') return 'Bal\u00ADanced';

      // Fallback: keep as-is (no risky hyphenation)
      return canonical;
    }

    String emojiFor(String label) {
      final normalized = label.replaceAll('\u00AD', '').trim();
      switch (normalized) {
        case 'High Protein':
          return '💪';
        case 'Low Carb':
          return '🥑';
        case 'Vegan':
          return '🌱';
        case 'Vegetarisch':
          return '🥕';
        case 'Glutenfrei':
          return '🌾';
        case 'Laktosefrei':
          return '🥛';
        case 'Kalorienarm':
          return '⚡';
        case 'High Calorie':
          return '🔥';
        default:
          return '🏷️';
      }
    }

    // Exactly 3 slots (UI spec). Keep layout stable.
    final slots = <String>[
      ...unique.map(prettyHyphenate),
      ...List.generate((3 - unique.length).clamp(0, 3), (_) => ''),
    ];

    return Row(
      children: [
        Expanded(
          child: _EmojiFactCard(
            emoji: slots[0].isNotEmpty ? emojiFor(slots[0]) : '🏷️',
            value: slots[0].isNotEmpty ? slots[0] : '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _EmojiFactCard(
            emoji: slots[1].isNotEmpty ? emojiFor(slots[1]) : '🏷️',
            value: slots[1].isNotEmpty ? slots[1] : '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _EmojiFactCard(
            emoji: slots[2].isNotEmpty ? emojiFor(slots[2]) : '🏷️',
            value: slots[2].isNotEmpty ? slots[2] : '—',
          ),
        ),
      ],
    );
    }
}

class _EmojiFactCard extends StatelessWidget {
  final String emoji;
  final String value;

  const _EmojiFactCard({
    required this.emoji,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
          return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GrocifyTheme.border.withOpacity(0.35), width: 1),
              boxShadow: [
                BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 18, height: 1.0),
                ),
          const SizedBox(height: 10),
                Text(
            value,
                  style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: GrocifyTheme.textPrimary,
              height: 1.18,
                    letterSpacing: -0.2,
                  ),
            maxLines: 2,
            overflow: TextOverflow.visible,
            softWrap: true,
                ),
              ],
      ),
    );
  }
}

// _MetaBadge entfernt - wird nicht mehr verwendet

// ============================================================================
// WARNINGS SECTION
// ============================================================================

class _WarningsSection extends StatelessWidget {
  final List<String> warnings;

  const _WarningsSection({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              GrocifyTheme.warning.withOpacity(0.12),
              GrocifyTheme.warning.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: GrocifyTheme.warning.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: GrocifyTheme.warning.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GrocifyTheme.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.info_rounded,
                size: 20,
                color: GrocifyTheme.warning,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings
                    .map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          warning,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: GrocifyTheme.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INGREDIENTS SECTION
// ============================================================================

class _IngredientsSection extends StatelessWidget {
  final List<String> ingredients;
  final List<String>? withoutOffers;
  final List<Offer?> offers;
  final List<RecipeOfferUsed>? offersUsed;
  final List<ExtraIngredient>? extraIngredients;
  final int servings;
  final Set<int> selectedIndices;
  final Set<int> selectedWithoutOfferIndices;
  final Function(int) onIngredientToggle;
  final Function(int) onWithoutOfferToggle;
  final Function(int) onServingsChanged;
  final BuildContext parentContext;

  const _IngredientsSection({
    required this.ingredients,
    this.withoutOffers,
    required this.offers,
    this.offersUsed,
    this.extraIngredients,
    required this.servings,
    required this.selectedIndices,
    required this.selectedWithoutOfferIndices,
    required this.onIngredientToggle,
    required this.onWithoutOfferToggle,
    required this.onServingsChanged,
    required this.parentContext,
  });

  /// Trennt Zutaten in Angebots-Zutaten und Basiszutaten
  List<Widget> _buildIngredientSections() {
    final List<Map<String, dynamic>> offerIngredients = [];
    final List<Map<String, dynamic>> basicIngredients = [];
    
    for (int i = 0; i < ingredients.length; i++) {
      final ingredient = ingredients[i];
      final offer = i < offers.length ? offers[i] : null;
      
      // Besseres Matching: Suche nach exactName oder name im ingredient string
      RecipeOfferUsed? offerUsed;
      final offersUsedList = offersUsed;
      if (offersUsedList != null && offersUsedList.isNotEmpty) {
        final ingredientName = ingredient.split('(').first.trim();
        try {
          offerUsed = offersUsedList.firstWhere(
            (ou) {
              final exactNameMatch = ou.exactName.isNotEmpty && 
                  (ingredientName.toLowerCase().contains(ou.exactName.toLowerCase()) ||
                   ou.exactName.toLowerCase().contains(ingredientName.toLowerCase()));
              return exactNameMatch;
            },
          );
        } catch (_) {
          // Fallback: Index-basiert wenn name-Matching fehlschlägt
          offerUsed = i < offersUsedList.length ? offersUsedList[i] : null;
        }
      }
      
      // Prüfe ob Basiszutat (kein offerUsed ODER priceEur == 0.0 ODER offerId leer)
      final ingredientName = ingredient.split('(').first.trim();
      final isBaseByName = _RecipeDetailScreenNewState._isBaseIngredientName(ingredientName);
      final isInOffer = offerUsed != null && offerUsed.priceEur > 0.0 && offerUsed.offerId.isNotEmpty;
      
      if (isInOffer) {
        offerIngredients.add({
          'index': i,
          'ingredient': ingredient,
          'offer': offer,
          'offerUsed': offerUsed,
        });
      } else if (isBaseByName) {
        basicIngredients.add({
          'index': i,
          'ingredient': ingredient,
          'offer': offer,
          'offerUsed': null,
        });
      } else {
        // Do NOT label these as "Kein Angebot" (requirement: only show non-offer if explicitly provided by without_offers).
        // Keep them in the main list without an offer status chip.
        offerIngredients.add({
          'index': i,
          'ingredient': ingredient,
          'offer': offer,
          'offerUsed': null,
        });
      }
    }
    
    final List<Widget> sections = [];
    
      // Angebots-Zutaten
    if (offerIngredients.isNotEmpty) {
      sections.add(
        Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: GrocifyTheme.border.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: offerIngredients.asMap().entries.map((entry) {
              final idx = entry.key;
              final data = entry.value;
              final index = data['index'] as int;
              final ingredient = data['ingredient'] as String;
              final offer = data['offer'] as Offer?;
              final offerUsed = data['offerUsed'] as RecipeOfferUsed?;
              final isLast = idx == offerIngredients.length - 1 && basicIngredients.isEmpty;

              return Column(
                children: [
                  _IngredientItem(
                    name: ingredient,
                    amount: _getAmountForIngredient(ingredient, offerUsed),
                    offer: offer,
                    offerUsed: offerUsed,
                    isChecked: selectedIndices.contains(index),
                    onToggle: () => onIngredientToggle(index),
                    isBasicIngredient: false,
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: GrocifyTheme.border.withOpacity(0.5),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }
    
    // Explicit without_offers section (only if provided by JSON schema)
    final wo = withoutOffers ?? const <String>[];
    if (wo.isNotEmpty) {
      sections.add(const SizedBox(height: 24));
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GrocifyTheme.warning.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.report_gmailerrorred_rounded,
                  size: 18,
                  color: GrocifyTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ohne Angebot',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: GrocifyTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      );
      sections.add(
        Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: GrocifyTheme.border.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: wo.asMap().entries.map((entry) {
              final idx = entry.key;
              final ingredient = entry.value;
              final isLast = idx == wo.length - 1;

              return Column(
                children: [
                  _IngredientItem(
                    name: ingredient,
                    amount: _getAmountForIngredient(ingredient, null),
                    offer: null,
                    offerUsed: null,
                    isChecked: selectedWithoutOfferIndices.contains(idx),
                    onToggle: () => onWithoutOfferToggle(idx),
                    isBasicIngredient: false,
                    isNotInOffer: true,
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: GrocifyTheme.border.withOpacity(0.5),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }
    
    // Basiszutaten Abschnitt
    if (basicIngredients.isNotEmpty) {
      sections.add(const SizedBox(height: 24));
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GrocifyTheme.textSecondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: GrocifyTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Basis Zutaten',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: GrocifyTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      );
      sections.add(
        Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: GrocifyTheme.border.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: basicIngredients.asMap().entries.map((entry) {
              final idx = entry.key;
              final data = entry.value;
              final index = data['index'] as int;
              final ingredient = data['ingredient'] as String;
              final offer = data['offer'] as Offer?;
              final isLast = idx == basicIngredients.length - 1;

              return Column(
                children: [
                  _IngredientItem(
                    name: ingredient,
                    amount: _getAmountForIngredient(ingredient, null),
                    offer: offer,
                    offerUsed: null,
                    isChecked: selectedIndices.contains(index),
                    onToggle: () => onIngredientToggle(index),
                    isBasicIngredient: true,
                    isNotInOffer: false,
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: GrocifyTheme.border.withOpacity(0.5),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }
    
    // Extra-Zutaten Sektion (falls vorhanden)
    if (extraIngredients != null && extraIngredients!.isNotEmpty) {
      sections.add(
        const SizedBox(height: 24),
      );
      sections.add(
        Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: GrocifyTheme.border.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header "Extra-Zutaten"
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 20,
                        color: GrocifyTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Extra-Zutaten',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: GrocifyTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Extra-Zutaten Liste
              ...extraIngredients!.asMap().entries.map((entry) {
                final idx = entry.key;
                final extraIng = entry.value;
                final isLast = idx == extraIngredients!.length - 1;
                
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _IngredientItem(
                        name: extraIng.name,
                        amount: extraIng.amount,
                        offer: null,
                        offerUsed: null,
                        isChecked: true,
                        onToggle: () {},
                        isBasicIngredient: true,
                      ),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: GrocifyTheme.border.withOpacity(0.5),
                        ),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
    
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), // px-5 pb-6
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 20,
                        color: GrocifyTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Zutaten',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GrocifyTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                // Portionen-Button (funktional)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      showDialog(
                        context: parentContext,
                        builder: (context) => AlertDialog(
                          backgroundColor: GrocifyTheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            'Portionen',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: GrocifyTheme.textPrimary,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(8, (index) {
                              final servingsValue = index + 1;
                              final isSelected = servingsValue == servings;
                              return RadioListTile<int>(
                                value: servingsValue,
                                groupValue: servings,
                                onChanged: (value) {
                                  if (value != null) {
                                    onServingsChanged(value);
                                    Navigator.pop(context);
                                    HapticFeedback.selectionClick();
                                  }
                                },
                                title: Text(
                                  '$servingsValue ${servingsValue == 1 ? 'Portion' : 'Portionen'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? GrocifyTheme.textPrimary : GrocifyTheme.textSecondary,
                                  ),
                                ),
                                activeColor: GrocifyTheme.primary,
                              );
                            }),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: GrocifyTheme.primary.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 18,
                            color: GrocifyTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$servings',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: GrocifyTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: GrocifyTheme.primary,
                ),
              ],
            ),
          ),
                  ),
                ),
              ],
            ),
          ),
          // Zutaten-Sektionen (Angebots-Zutaten + Basiszutaten)
          ..._buildIngredientSections(),
        ],
      ),
    );
  }

  String _getAmountForIngredient(String ingredient, RecipeOfferUsed? offerUsed) {
    // Wenn offerUsed vorhanden ist, verwende quantity + unit
    if (offerUsed != null) {
      if (offerUsed.quantity != null && offerUsed.unit.isNotEmpty) {
        // Format: "500 g" oder "3 Stück"
        final quantity = offerUsed.quantity!.toStringAsFixed(offerUsed.quantity! % 1 == 0 ? 0 : 1);
        return '$quantity ${offerUsed.unit}';
      } else if (offerUsed.unit.isNotEmpty) {
        return offerUsed.unit;
      }
    }
    
    // Fallback: Versuche aus ingredient string zu extrahieren (z.B. "Pasta (500g)")
    if (ingredient.contains('(') && ingredient.contains(')')) {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(ingredient);
      if (match != null) {
        return match.group(1) ?? '';
      }
    }
    
    // Fallback: Heuristik basierend auf Name
    final lower = ingredient.toLowerCase();
    if (lower.contains('spaghetti') || lower.contains('nudel')) {
      return '250g';
    } else if (lower.contains('speck')) {
      return '150g';
    } else if (lower.contains('ei')) {
      return '3 Stück';
    } else if (lower.contains('parmesan')) {
      return '80g';
    } else if (lower.contains('knoblauch')) {
      return '2 Zehen';
    } else if (lower.contains('öl')) {
      return '2 EL';
    }
    return 'nach Bedarf';
  }
}

class _IngredientItem extends StatelessWidget {
  final String name;
  final String amount;
  final Offer? offer;
  final RecipeOfferUsed? offerUsed;
  final bool isChecked;
  final VoidCallback onToggle;
  final bool isBasicIngredient;
  final bool isNotInOffer;

  const _IngredientItem({
    required this.name,
    required this.amount,
    this.offer,
    this.offerUsed,
    required this.isChecked,
    required this.onToggle,
    this.isBasicIngredient = false,
    this.isNotInOffer = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(
        0,
      ), // No border radius for seamless list
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Linke Seite: Checkbox + Info
                          Expanded(
                            child: Row(
                              children: [
                                // Checkbox (modernisiert mit Animation)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? GrocifyTheme.primary
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isChecked
                                          ? GrocifyTheme.primary
                                          : GrocifyTheme.border.withOpacity(0.4),
                                      width: 1.6,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: isChecked
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                // Zutat-Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              offerUsed?.exactName.isNotEmpty == true 
                                                  ? offerUsed!.exactName 
                                                  : name.split('(').first.trim(),
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: isChecked
                                              ? GrocifyTheme.textPrimary
                                              : GrocifyTheme.textPrimary.withOpacity(0.85),
                                          letterSpacing: -0.3,
                                          decoration: isChecked ? null : TextDecoration.none,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                          ),
                                          // Status-Badge (Angebot / Nicht im Angebot / Basis)
                                          if (!isChecked &&
                                              (isBasicIngredient ||
                                                  isNotInOffer ||
                                                  offerUsed != null ||
                                                  offer != null)) ...[
                                            const SizedBox(width: 8),
                                            _StatusChip(
                                              label: isBasicIngredient
                                                  ? 'Basis'
                                                  : (isNotInOffer ? 'Kein Angebot' : 'Angebot'),
                                              color: isBasicIngredient
                                                  ? GrocifyTheme.textSecondary
                                                  : (isNotInOffer ? GrocifyTheme.warning : GrocifyTheme.success),
                                      ),
                                          ],
                                          // Marke entfernt (cleaner)
                                        ],
                                      ),
                                      if (amount.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          amount,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: GrocifyTheme.textTertiary,
                                          ),
                                        ),
                                      ],
                              ],
                            ),
                          ),
                              ],
                            ),
                          ),
            // Rechte Seite: Preis (minimalistisch)
            if (!isBasicIngredient && !isNotInOffer && offerUsed != null && offerUsed!.priceEur > 0) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Preis vorher (durchgestrichen) - nur anzeigen wenn vorhanden
                  if (offerUsed!.priceBeforeEur != null && offerUsed!.priceBeforeEur! > 0 && offerUsed!.priceBeforeEur! > offerUsed!.priceEur)
                    Text(
                      '${offerUsed!.priceBeforeEur!.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: GrocifyTheme.textTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  if (offerUsed!.priceBeforeEur != null && offerUsed!.priceBeforeEur! > 0 && offerUsed!.priceBeforeEur! > offerUsed!.priceEur)
                    const SizedBox(height: 2),
                  // Aktueller Preis
                  Text(
                    '${offerUsed!.priceEur.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GrocifyTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ] else if (!isBasicIngredient && !isNotInOffer && offer != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Standardpreis (durchgestrichen wenn Loyalty-Preis vorhanden)
                  if (offer!.hasLoyaltyPrice)
                    Text(
                      '${offer!.standardPriceValue.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: GrocifyTheme.textTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    )
                  else
                    Text(
                      '${offer!.standardPriceValue.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: GrocifyTheme.textPrimary,
                      ),
                    ),
                  // Loyalty-Preis (falls vorhanden)
                  if (offer!.hasLoyaltyPrice) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: GrocifyTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: GrocifyTheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.card_membership_rounded,
                                size: 14,
                                color: GrocifyTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${offer!.loyaltyPriceValue!.toStringAsFixed(2)} €',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: GrocifyTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (offer!.condition?.label != null || offer!.loyaltyPrice?.condition != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: GrocifyTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: GrocifyTheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          offer!.condition?.label ??
                              offer!.loyaltyPrice?.condition ??
                              'Mit Karte',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: GrocifyTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                  // Einheit anzeigen (falls vorhanden)
                  if (offer!.unit != null && offer!.unit!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'pro ${offer!.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: GrocifyTheme.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              Text(
                'Preis nicht verfügbar',
                style: TextStyle(
                  fontSize: 13,
                  color: GrocifyTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

// ============================================================================
// STEPS SECTION
// ============================================================================

class _StepsSection extends StatefulWidget {
  final List<String> steps;

  const _StepsSection({required this.steps});

  @override
  State<_StepsSection> createState() => _StepsSectionState();
}

class _StepsSectionState extends State<_StepsSection> {
  bool _isExpanded = true; // Direkt geöffnet

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titel mit Expand/Collapse Button
          Material(
            color: Colors.transparent,
            child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              HapticFeedback.selectionClick();
            },
              borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: GrocifyTheme.textSecondary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 18,
                            color: GrocifyTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                  Text(
                    'Zubereitung',
                    style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: GrocifyTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.expand_more_rounded,
                    color: GrocifyTheme.textSecondary,
                        size: 24,
                      ),
                  ),
                ],
                ),
              ),
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            // Steps-Liste (minimalistisch)
            Container(
              decoration: BoxDecoration(
                color: GrocifyTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: GrocifyTheme.border.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: widget.steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  final isLast = index == widget.steps.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Schritt-Nummer Badge (minimalistisch)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: GrocifyTheme.primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: GrocifyTheme.primary.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: GrocifyTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Schritt-Text
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  step,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: GrocifyTheme.textPrimary,
                                    height: 1.65,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(
                          height: 1,
                          thickness: 1,
                            color: GrocifyTheme.border.withOpacity(0.2),
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM ACTIONS
// ============================================================================

class _BottomActions extends StatelessWidget {
  final VoidCallback onAddToMealPlan;
  final VoidCallback onAddToShoppingList;

  const _BottomActions({
    required this.onAddToMealPlan,
    required this.onAddToShoppingList,
  });

  @override
  Widget build(BuildContext context) {
    // UI-only: restore previous two-button layout (as requested)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        border: Border(
          top: BorderSide(
            color: GrocifyTheme.border.withOpacity(0.4),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, -8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Button 1 - Primär (wie vorher)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAddToMealPlan,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              GrocifyTheme.primary,
                              GrocifyTheme.primaryLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: GrocifyTheme.primary.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Zum Wochenplan hinzufügen',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Button 2 - Sekundär (wie vorher)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAddToShoppingList,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: GrocifyTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: GrocifyTheme.border.withOpacity(0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 22,
                              color: GrocifyTheme.textPrimary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Zur Einkaufsliste hinzufügen',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: GrocifyTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
