/// Home Screen - Grocify Home Dashboard
/// Pixel-nah am spezifizierten Design, Business-Logik unverändert
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/recipe.dart';
import '../../data/services/meal_plan_service.dart';
import '../../data/services/stats_service.dart';
import '../../data/repositories/cached_recipe_repository.dart';
import '../discover/recipe_detail_screen_new.dart';
import '../settings/settings_screen.dart';
import '../onboarding/onboarding_repository.dart';
import '../onboarding/utils/preference_matcher.dart';
import '../recipes/presentation/recipes_screen.dart';
import '../../widgets/water_tracker_card.dart';
import '../../core/widgets/molecules/recipe_preview_card.dart';
import 'day_reflection_screen.dart';
import '../../app/main_navigation.dart';
import '../auth/data/auth_service_local.dart';
import '../recipes/domain/recipe_ranking_service.dart';
import '../customer/data/customer_data_store.dart';
import '../recipes/domain/recipe_personalization_service.dart';

// Design Colors (Stone/Emerald Palette)
class _HomeDesignColors {
  _HomeDesignColors._();

  // Background
  static const Color background = Color(0xFFFAFAF9); // stone-50

  // Text
  static const Color textPrimary = Color(0xFF1C1917); // stone-900
  static const Color textSecondary = Color(0xFF78716C); // stone-500

  // Accent
  static const Color accentEmerald = Color(0xFF10B981); // emerald-500

  // Borders & Surfaces
  static const Color border = Color(0xFFE7E5E4); // stone-200
  static const Color surface = Colors.white;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MealPlanService _mealPlanService = MealPlanService.instance;
  final StatsService _statsService = StatsService.instance;
  
  // Cached upcoming recipes for today
  List<_PlannedRecipeEntry> _cachedUpcomingRecipes = [];

  // Water tracking state
  double _waterAmount = 0.0; // in liters
  final double _waterGoal = 3.0; // liters

  // Weight tracking state
  double _currentWeight = 75.0; // in kg (initial value, should be loaded from prefs)
  final double _startWeight = 80.0; // initial weight when user started

  // Weekly highlights - cached for performance
  List<Recipe> _weeklyHighlights = [];
  bool _isLoadingHighlights = true;

  // Settings state
  SharedPreferences? _prefs;
  bool _showWaterGoal = true;
  bool _showWeightTracking = true;
  
  // Calendar/Streak state (Dummy data für jetzt)
  Set<int> _activeDays = {1, 2, 4, 7, 12, 13}; // Days of month where recipes were cooked
  int _currentStreak = 7; // Dummy streak days
  DateTime _lastCookedDay = DateTime.now().subtract(const Duration(days: 0)); // Dummy
  int _totalRecipes = 24; // Dummy total recipes

  @override
  void initState() {
    super.initState();
    _mealPlanService.addListener(_onMealPlanChanged);
    _loadWeeklyHighlights();
    _updateCachedUpcomingRecipes();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _showWaterGoal = _prefs?.getBool('home_show_water_goal') ?? true;
      _showWeightTracking = _prefs?.getBool('home_show_weight_tracking') ?? true;
    });
  }

  @override
  void dispose() {
    _mealPlanService.removeListener(_onMealPlanChanged);
    super.dispose();
  }

  void _onMealPlanChanged() {
    _loadWeeklyHighlights();
    _updateCachedUpcomingRecipes();
    setState(() {});
  }
  
  void _updateCachedUpcomingRecipes() {
    _cachedUpcomingRecipes = _getUpcomingRecipesForToday();
  }
  
  List<_PlannedRecipeEntry> _getUpcomingRecipesForToday() {
    final today = DateTime.now();
    final todayRecipes = _mealPlanService.getRecipesForDate(today);
    
    final entries = <_PlannedRecipeEntry>[];
    todayRecipes.forEach((mealType, recipe) {
      if (recipe != null) {
        entries.add(_PlannedRecipeEntry(
          recipe: recipe,
          date: today,
          mealType: mealType,
        ));
      }
    });
    
    // Sort by meal type order (breakfast, lunch, dinner)
    entries.sort((a, b) => a.mealType.index.compareTo(b.mealType.index));
    return entries;
  }

  Future<void> _loadWeeklyHighlights() async {
    setState(() => _isLoadingHighlights = true);
    try {
      final allRecipes = await CachedRecipeRepository.instance.loadAllCached();
      // Filter out already planned recipes
      final plannedRecipes = _mealPlanService.getPlannedRecipes();
      final plannedRecipeIds = plannedRecipes.map((r) => r.id).toSet();

      var availableRecipes = allRecipes
          .where((r) => !plannedRecipeIds.contains(r.id))
          .where((r) => r.retailer.toUpperCase() != 'KAUFLAND')
          .toList();

      // Load current user profile (new local auth storage), fallback to onboarding prefs
      final user = await AuthServiceLocal.instance.getCurrentUser();
      final onboardingProfile = user == null ? await OnboardingRepository.loadUserProfile() : null;

      if (user != null) {
        final ranker = RecipeRankingService.instance;
        availableRecipes.sort((a, b) {
          final sa = ranker.score(a, user.profile);
          final sb = ranker.score(b, user.profile);
          if (sa != sb) return sb.compareTo(sa);
          final savingsA = a.savings ?? 0.0;
          final savingsB = b.savings ?? 0.0;
          if (savingsA != savingsB) return savingsB.compareTo(savingsA);
          final priceA = a.price ?? double.infinity;
          final priceB = b.price ?? double.infinity;
          return priceA.compareTo(priceB);
        });

        // Personalization (stable) on top of ranking order (no recipe reload).
        final pref = await RecipePersonalizationService.instance.loadPrefsForUid(user.uid);
        availableRecipes = RecipePersonalizationService.instance
            .personalize(recipes: availableRecipes, prefs: pref.prefs, source: pref.source)
            .recipes;
      } else {
        // Legacy fallback
        availableRecipes = PreferenceMatcher.sortByPreferences(availableRecipes, onboardingProfile);
        availableRecipes.sort((a, b) {
          final savingsA = a.savings ?? 0.0;
          final savingsB = b.savings ?? 0.0;
          if (savingsA != savingsB) {
            return savingsB.compareTo(savingsA);
          }
          final priceA = a.price ?? double.infinity;
          final priceB = b.price ?? double.infinity;
          return priceA.compareTo(priceB);
        });
      }

      // Diversity: do not show only one market (round-robin across markets)
      final byMarket = <String, List<Recipe>>{};
      for (final r in availableRecipes) {
        final market = (r.market ?? '').toLowerCase().trim();
        final key = market.isNotEmpty ? market : r.retailer.toLowerCase().trim();
        byMarket.putIfAbsent(key, () => <Recipe>[]).add(r);
      }
      final marketOrder = byMarket.keys.toList();
      marketOrder.sort((a, b) => byMarket[b]!.length.compareTo(byMarket[a]!.length));
      final diversified = <Recipe>[];
      var guard = 0;
      while (diversified.length < 10 && diversified.length < availableRecipes.length && guard < 300) {
        guard++;
        var progressed = false;
        for (final m in marketOrder) {
          final list = byMarket[m]!;
          if (list.isEmpty) continue;
          diversified.add(list.removeAt(0));
          progressed = true;
          if (diversified.length >= 10) break;
        }
        if (!progressed) break;
      }
      setState(() {
        _weeklyHighlights = diversified.isNotEmpty ? diversified : availableRecipes.take(10).toList();
        _isLoadingHighlights = false;
      });
    } catch (e) {
      debugPrint('Error loading highlights: $e');
      setState(() => _isLoadingHighlights = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeDesignColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header mit Top-Right Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _HeaderSection()),
                  _TopRightIconsBar(
                    onStreakTap: () => _showStreakModal(context),
                    onCalendarTap: () => _showCalendarModal(context),
                    onSettingsTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. Kombinierte Card "Heute auf einen Blick" + Plan (ohne Überschrift)
              _TodayAndPlanCard(
                statsService: _statsService,
                mealPlanService: _mealPlanService,
                upcomingRecipes: _cachedUpcomingRecipes,
                onRecipeTap: (recipe) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          RecipeDetailScreenNew(recipe: recipe),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                            ),
                            child: child,
                          ),
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // 3. Highlights der Woche
              _HighlightsSection(
                highlights: _weeklyHighlights,
                isLoading: _isLoadingHighlights,
              ),

              const SizedBox(height: 24),

              // 4. Wasserzähler Card (mit Überschrift) - nur wenn aktiviert
              if (_showWaterGoal) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                'Wassertracker',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _HomeDesignColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WaterTrackerCard(
                    currentLitres: _waterAmount,
                    goalLitres: _waterGoal,
                    totalCups: 8,
                    onCupTap: (cupIndex) {
                      setState(() {
                        const litresPerCup = 0.25;
                        final targetLitres = (cupIndex + 1) * litresPerCup;
                        _waterAmount = targetLitres.clamp(0.0, _waterGoal * 1.5);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ],

              // 5. Gewichtstracker Card (mit Überschrift) - nur wenn aktiviert
              if (_showWeightTracking) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gewichtstracker',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _HomeDesignColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WeightTrackerCard(
                    currentWeight: _currentWeight,
                    startWeight: _startWeight,
                    onWeightChange: (delta) {
                      setState(() {
                        _currentWeight = (_currentWeight + delta).clamp(30.0, 300.0);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ],

              // 6. Tages-Intention Card (mit Überschrift)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tagesreflektion',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _HomeDesignColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DayIntentionCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DayReflectionScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Bottom padding for navigation
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  void _showStreakModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _StreakModal(
        currentStreak: _currentStreak,
        lastCookedDay: _lastCookedDay,
      ),
    );
  }

  void _showCalendarModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CalendarModal(
        activeDays: _activeDays,
        currentStreak: _currentStreak,
        totalRecipes: _totalRecipes,
      ),
    );
  }
}

// ============================================================================
// WIDGET SECTIONS
// ============================================================================

/// Header: Begrüßung mit Titel und Untertitel
class _HeaderSection extends StatefulWidget {
  const _HeaderSection();

  @override
  State<_HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<_HeaderSection> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final customerProfile = await CustomerDataStore.instance.loadProfile();
      if (mounted) {
        setState(() {
          _userName = customerProfile?.name?.trim();
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _userName != null && _userName!.isNotEmpty
        ? 'Heyy $_userName 👋'
        : 'Heyy 👋';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _HomeDesignColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        // Zitat-Box (ENHANCED) mit Amber-Gradient
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.topRight,
                  colors: [
                    Color(0xFFFFFBEB), // amber-50
                    Color(0xFFFFF7ED), // orange-50
                    Color(0xFFFFFBEB), // amber-50
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFDE68A).withOpacity(0.6), // amber-200/60
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji ✨
                  const Text(
                    '✨',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  // Text
                  Flexible(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
            fontSize: 15,
                          letterSpacing: -0.025,
            height: 1.4,
          ),
                        children: [
                          TextSpan(
                            text: 'Kleine Schritte, ',
                            style: TextStyle(
                              color: const Color(0xFF292524), // stone-800
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: 'große Ersparnisse',
                            style: TextStyle(
                              color: const Color(0xFFB45309), // amber-700
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Overlay Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.topRight,
                    colors: [
                      const Color(0xFFFEF3C7).withOpacity(0.0), // amber-100/0
                      const Color(0xFFFEF3C7).withOpacity(0.4), // amber-100/40
                      const Color(0xFFFEF3C7).withOpacity(0.0), // amber-100/0
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Top-Right Icons Bar (Streak, Kalender, Settings)
class _TopRightIconsBar extends StatelessWidget {
  final VoidCallback onStreakTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onSettingsTap;

  const _TopRightIconsBar({
    required this.onStreakTap,
    required this.onCalendarTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopIconButton(
          icon: Icons.local_fire_department_rounded,
          onTap: onStreakTap,
          tooltip: 'Streak',
          gradientColors: const [
            Color(0xFFFB923C), // orange-400
            Color(0xFFF97316), // orange-500
          ],
          shadowColor: const Color(0xFFF97316).withOpacity(0.3),
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          icon: Icons.calendar_month_rounded,
          onTap: onCalendarTap,
          tooltip: 'Kalender',
          gradientColors: const [
            Color(0xFFF472B6), // pink-400
            Color(0xFFEC4899), // pink-500
          ],
          shadowColor: const Color(0xFFEC4899).withOpacity(0.3),
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          icon: Icons.settings_rounded,
          onTap: onSettingsTap,
          tooltip: 'Einstellungen',
          gradientColors: const [
            Color(0xFF44403C), // stone-700
            Color(0xFF1C1917), // stone-900
          ],
          shadowColor: const Color(0xFF1C1917).withOpacity(0.2),
        ),
      ],
    );
  }
}

/// Single Icon Button for Top-Right Bar
class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final List<Color> gradientColors;
  final Color shadowColor;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.gradientColors,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Kombinierte Card "Heute auf einen Blick" + Plan
class _TodayAndPlanCard extends StatefulWidget {
  final StatsService statsService;
  final MealPlanService mealPlanService;
  final List<_PlannedRecipeEntry> upcomingRecipes;
  final Function(Recipe) onRecipeTap;

  const _TodayAndPlanCard({
    required this.statsService,
    required this.mealPlanService,
    required this.upcomingRecipes,
    required this.onRecipeTap,
  });

  @override
  State<_TodayAndPlanCard> createState() => _TodayAndPlanCardState();
}

class _TodayAndPlanCardState extends State<_TodayAndPlanCard> {
  @override
  void initState() {
    super.initState();
    widget.mealPlanService.addListener(_onPlanChanged);
  }

  @override
  void dispose() {
    widget.mealPlanService.removeListener(_onPlanChanged);
    super.dispose();
  }

  void _onPlanChanged() {
    setState(() {});
  }

  String _getEmojiForRecipe(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('pasta') || lower.contains('nudel') || lower.contains('spaghetti')) {
      return '🍝';
    } else if (lower.contains('salat') || lower.contains('salad')) {
      return '🥗';
    } else if (lower.contains('curry')) {
      return '🍛';
    } else if (lower.contains('hähnchen') || lower.contains('chicken')) {
      return '🍗';
    } else if (lower.contains('pizza')) {
      return '🍕';
    } else if (lower.contains('burger')) {
      return '🍔';
    } else if (lower.contains('sushi')) {
      return '🍣';
    } else if (lower.contains('taco')) {
      return '🌮';
    } else if (lower.contains('bowl')) {
      return '🥙';
    } else if (lower.contains('suppe') || lower.contains('soup')) {
      return '🍲';
    } else if (lower.contains('reis') || lower.contains('rice')) {
      return '🍚';
    } else if (lower.contains('frühstück') || lower.contains('breakfast') || lower.contains('müsli')) {
      return '🥣';
    } else {
      return '🍽️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUpcomingRecipes = widget.upcomingRecipes.isNotEmpty;
    final nextRecipe = hasUpcomingRecipes ? widget.upcomingRecipes.first.recipe : null;

    return hasUpcomingRecipes && nextRecipe != null
          ? _buildHeroCard(nextRecipe)
        : _buildEmptyPlanState();
  }

  Widget _buildHeroCard(Recipe recipe) {
    final emoji = _getEmojiForRecipe(recipe.title);
    final duration = recipe.durationMinutes ?? 25;
    final servings = recipe.servings ?? 2;

    return GestureDetector(
      onTap: () => widget.onRecipeTap(recipe),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _HomeDesignColors.accentEmerald,
              const Color(0xFF059669), // emerald-600
              const Color(0xFF047857), // emerald-700
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _HomeDesignColors.accentEmerald.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Pattern Overlay (dekorative Kreise)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Stack(
                  children: [
                    // Kreis 1 (Oben Rechts)
                    Positioned(
                      top: -64,
                      right: -64,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Kreis 2 (Unten Links)
                    Positioned(
                      bottom: -48,
                      left: -48,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  Text(
                    'ALS NÄCHSTES AUF DEINEM PLAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Content Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linke Seite (Text)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titel
                            Text(
                              recipe.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Meta-Informationen
                            Row(
                              children: [
                                Text(
                                  '$duration Min',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '•',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$servings Portionen',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Button
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => widget.onRecipeTap(recipe),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Details ansehen',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _HomeDesignColors.accentEmerald,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Rechte Seite (Emoji-Container)
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlanState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _HomeDesignColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _HomeDesignColors.border.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Noch nichts auf deinem Plan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _HomeDesignColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lass uns deine Woche mit einem leckeren Gericht starten.',
            style: TextStyle(
              fontSize: 14,
              color: _HomeDesignColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                // Go to Recipes tab so user can pick a recipe to plan
                final nav = MainNavigationScope.maybeOf(context);
                if (nav != null) {
                  nav.setTab(1);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesScreen()));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _HomeDesignColors.accentEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Rezept planen',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Planned Recipe Entry
class _PlannedRecipeEntry {
  final Recipe recipe;
  final DateTime date;
  final MealType mealType;

  _PlannedRecipeEntry({
    required this.recipe,
    required this.date,
    required this.mealType,
  });
}

/// Highlights Section - Horizontal Scroll
class _HighlightsSection extends StatefulWidget {
  final List<Recipe> highlights;
  final bool isLoading;

  const _HighlightsSection({
    required this.highlights,
    required this.isLoading,
  });

  @override
  State<_HighlightsSection> createState() => _HighlightsSectionState();
}

class _HighlightsSectionState extends State<_HighlightsSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Highlights der Woche',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _HomeDesignColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        widget.isLoading
            ? const Center(child: CircularProgressIndicator())
            : widget.highlights.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 48,
                        color: _HomeDesignColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keine Highlights verfügbar',
                        style: TextStyle(
                          fontSize: 14,
                          color: _HomeDesignColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: widget.highlights.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final recipe = widget.highlights[index];
                    return _HighlightRecipeCard(recipe: recipe);
                  },
                ),
              ),
      ],
    );
  }
}

/// Highlight Recipe Card - verwendet neue RecipePreviewCard
class _HighlightRecipeCard extends StatefulWidget {
  final Recipe recipe;

  const _HighlightRecipeCard({required this.recipe});

  @override
  State<_HighlightRecipeCard> createState() => _HighlightRecipeCardState();
}

class _HighlightRecipeCardState extends State<_HighlightRecipeCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return RecipePreviewCard(
      recipe: widget.recipe,
      isFavorite: _isFavorite,
      width: 176,
      height: 200,
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RecipeDetailScreenNew(recipe: widget.recipe),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 0.05);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );
              var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: curve),
              );

              return FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      },
      onFavoriteTap: () {
        setState(() {
          _isFavorite = !_isFavorite;
        });
      },
    );
  }
}

/// Tages-Intention Card (Morgen/Abend)
class _DayIntentionCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _DayIntentionCard({this.onTap});

  bool _isEvening() {
    final hour = DateTime.now().hour;
    return hour >= 16; // Ab 16:00 Uhr = Abend
  }

  @override
  Widget build(BuildContext context) {
    final isEvening = _isEvening();
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _HomeDesignColors.accentEmerald,
              const Color(0xFF059669), // emerald-600
              const Color(0xFF047857), // emerald-700
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon links
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isEvening ? Icons.nightlight_round : Icons.wb_sunny,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEvening
                        ? 'Lass uns den Tag reflektieren 🌙'
                        : 'Lass uns in den Tag starten ☀️',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEvening
                        ? 'Nimm dir einen Moment für dich.'
                        : 'Beginne mit einer kurzen Atmung und setze deine Intention.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            // Pfeil rechts
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gewichtstracker Card
class _WeightTrackerCard extends StatelessWidget {
  final double currentWeight;
  final double startWeight;
  final Function(double delta) onWeightChange;

  const _WeightTrackerCard({
    required this.currentWeight,
    required this.startWeight,
    required this.onWeightChange,
  });

  @override
  Widget build(BuildContext context) {
    final weightDiff = currentWeight - startWeight;
    final isLoss = weightDiff < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _HomeDesignColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _HomeDesignColors.border.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge rechts oben (Titel wird außerhalb angezeigt)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (weightDiff != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLoss
                        ? _HomeDesignColors.accentEmerald.withOpacity(0.1)
                        : _HomeDesignColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${weightDiff > 0 ? '+' : ''}${weightDiff.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLoss
                          ? _HomeDesignColors.accentEmerald
                          : _HomeDesignColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Große Zahl (zentriert)
          Center(
            child: Column(
              children: [
                Text(
                  currentWeight.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: _HomeDesignColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _HomeDesignColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Plus/Minus Buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onWeightChange(-0.5),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _HomeDesignColors.accentEmerald,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => onWeightChange(0.5),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _HomeDesignColors.accentEmerald,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Startgewicht
          Center(
            child: Text(
              'Startgewicht: ${startWeight.toStringAsFixed(1)} kg',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _HomeDesignColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak Modal BottomSheet
class _StreakModal extends StatelessWidget {
  final int currentStreak;
  final DateTime lastCookedDay;

  const _StreakModal({
    required this.currentStreak,
    required this.lastCookedDay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed Header
          Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
                // Header mit Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFB923C), // orange-400
                            Color(0xFFF97316), // orange-500
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          Text(
                            'Dein Streak',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
                          Text(
                            'Halte die Serie am Laufen!',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Große Flamme in der Mitte (zentriert)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors.outlineVariant.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 120,
                            color: const Color(0xFFF97316),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '$currentStreak',
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentStreak == 1 ? 'Tag in Folge' : 'Tage in Folge',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Info Cards (mehr Details)
                  Row(
                    children: [
                      Expanded(
                        child: _KPICard(
                          icon: Icons.calendar_today_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'Letzter Tag',
                          value: _formatDateShort(lastCookedDay),
                          suffix: '',
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KPICard(
                          icon: Icons.trending_up_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          label: 'Bestes Ergebnis',
                          value: '$currentStreak',
                          suffix: ' Tage',
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Zusätzliche Info-Boxen
          Container(
                    padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.outlineVariant.withOpacity(0.3),
                        width: 1,
                      ),
            ),
            child: Row(
              children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 24,
                            color: const Color(0xFFF97316),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                Text(
                                'Nächster Meilenstein',
                  style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${((currentStreak / 7).ceil() * 7)} Tage',
                                style: TextStyle(
                                  fontSize: 16,
                    fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Motivation Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFF7ED).withOpacity(0.8),
                          const Color(0xFFFFEDD5).withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFB923C).withOpacity(0.2),
                        width: 1,
                      ),
            ),
            child: Row(
              children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: const Color(0xFFF97316),
                        ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                            'Koche heute ein Rezept, um deinen Streak zu halten! 🔥',
                    style: TextStyle(
                      fontSize: 14,
                              fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                              height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Heute';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Gest.';
    }
    return '${date.day}.${date.month}';
  }
}

/// Calendar Modal BottomSheet
class _CalendarModal extends StatelessWidget {
  final Set<int> activeDays;
  final int currentStreak;
  final int totalRecipes;

  const _CalendarModal({
    required this.activeDays,
    required this.currentStreak,
    required this.totalRecipes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    
    // Weekday headers
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    
    // Build calendar grid
    final calendarDays = <Widget>[];
    
    // Empty cells for days before month starts
    for (int i = 1; i < firstWeekday; i++) {
      calendarDays.add(const SizedBox());
    }
    
    // Days of month
    for (int day = 1; day <= daysInMonth; day++) {
      final isActive = activeDays.contains(day);
      final isToday = day == now.day;
      calendarDays.add(_CalendarDayCell(
        day: day,
        isActive: isActive,
        isToday: isToday,
        colors: colors,
      ));
    }
    
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed Header
          Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
                // Header mit Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF472B6), // pink-400
                            Color(0xFFEC4899), // pink-500
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          Text(
            _getMonthName(month) + ' $year',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
                          Text(
                            'Deine Aktivitäten im Überblick',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // Weekday headers
          Row(
            children: weekdays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            )).toList(),
          ),
                  const SizedBox(height: 12),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
            ),
            itemCount: calendarDays.length,
            itemBuilder: (context, index) => calendarDays[index],
          ),
          const SizedBox(height: 24),
                  // Stats Cards
                  Row(
            children: [
                      Expanded(
                        child: _KPICard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFF97316),
                label: 'Streak',
                          value: '$currentStreak',
                          suffix: ' Tag${currentStreak != 1 ? 'e' : ''}',
                colors: colors,
              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KPICard(
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'Aktiv',
                          value: '${activeDays.length}',
                          suffix: ' / $daysInMonth',
                colors: colors,
              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KPICard(
                          icon: Icons.restaurant_menu_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          label: 'Rezepte',
                          value: '$totalRecipes',
                          suffix: '',
                          colors: colors,
                        ),
                      ),
            ],
          ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
                    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];
    return months[month - 1];
  }
}

/// Calendar Day Cell
class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isActive;
  final bool isToday;
  final ColorScheme colors;

  const _CalendarDayCell({
    required this.day,
    required this.isActive,
    required this.isToday,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? colors.primary : colors.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: colors.primary, width: 2) : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? colors.onPrimary : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// KPI Card for Calendar Modal
class _KPICard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String suffix;
  final ColorScheme colors;

  const _KPICard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.suffix,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                      fontWeight: FontWeight.w600,
                color: colors.onSurface.withOpacity(0.6),
              ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
              value,
              style: TextStyle(
                      fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (suffix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withOpacity(0.7),
                      ),
              ),
            ),
          ],
        ),
          ],
      ),
    );
  }
}

/// Settings Modal BottomSheet
// ignore: unused_element
class _SettingsModal extends StatelessWidget {
  final SharedPreferences? prefs;
  final bool dailyReminders;
  final bool showWaterGoal;
  final bool showWeightTracking;
  final String weekStart;
  final ValueChanged<bool> onDailyRemindersChanged;
  final ValueChanged<bool> onShowWaterGoalChanged;
  final ValueChanged<bool> onShowWeightTrackingChanged;
  final ValueChanged<String> onWeekStartChanged;
  final VoidCallback onResetData;

  const _SettingsModal({
    required this.prefs,
    required this.dailyReminders,
    required this.showWaterGoal,
    required this.showWeightTracking,
    required this.weekStart,
    required this.onDailyRemindersChanged,
    required this.onShowWaterGoalChanged,
    required this.onShowWeightTrackingChanged,
    required this.onWeekStartChanged,
    required this.onResetData,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed Header
          Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
                // Header mit Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF44403C), // stone-700
                            Color(0xFF1C1917), // stone-900
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1C1917).withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          Text(
            'Einstellungen',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
                          Text(
                            'Personalisierung & Präferenzen',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Zurück Button
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfaceContainerHighest,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // Allgemeine Einstellungen
          _SettingsSection(
            title: 'Allgemein',
            icon: Icons.settings_rounded,
            colors: colors,
            children: [
              _SettingsItem(
                icon: Icons.notifications_rounded,
                title: 'Tägliche Erinnerungen',
                        subtitle: 'Erhalte tägliche Benachrichtigungen',
                trailing: Switch(
                  value: dailyReminders,
                  onChanged: onDailyRemindersChanged,
                          activeColor: const Color(0xFF10B981),
                ),
                colors: colors,
              ),
              _Divider(colors: colors),
              _SettingsItem(
                icon: Icons.calendar_today_rounded,
                title: 'Start der Woche',
                        subtitle: 'Wochenbeginn festlegen',
                trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.outlineVariant.withOpacity(0.3),
                              width: 1,
                            ),
                  ),
                  child: DropdownButton<String>(
                    value: weekStart,
                    underline: const SizedBox(),
                            dropdownColor: colors.surface,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                    items: const [
                              DropdownMenuItem(
                                value: 'Montag',
                                child: Text('Montag'),
                              ),
                              DropdownMenuItem(
                                value: 'Sonntag',
                                child: Text('Sonntag'),
                              ),
                    ],
                    onChanged: (value) {
                      if (value != null) onWeekStartChanged(value);
                    },
                  ),
                ),
                colors: colors,
              ),
            ],
          ),
          
                  const SizedBox(height: 20),
          
          // Anzeige-Einstellungen
          _SettingsSection(
            title: 'Anzeige',
            icon: Icons.visibility_rounded,
            colors: colors,
            children: [
              _SettingsItem(
                icon: Icons.water_drop_rounded,
                        title: 'Wasserziel',
                        subtitle: 'Wasser-Tracker auf dem Home-Screen',
                trailing: Switch(
                  value: showWaterGoal,
                  onChanged: onShowWaterGoalChanged,
                          activeColor: const Color(0xFF10B981),
                ),
                colors: colors,
              ),
              _Divider(colors: colors),
              _SettingsItem(
                icon: Icons.monitor_weight_rounded,
                        title: 'Gewichtstracking',
                        subtitle: 'Gewichtsverlauf anzeigen',
                trailing: Switch(
                  value: showWeightTracking,
                  onChanged: onShowWeightTrackingChanged,
                          activeColor: const Color(0xFF10B981),
                ),
                colors: colors,
              ),
            ],
          ),
          
                  const SizedBox(height: 20),
          
          // Daten-Einstellungen
          _SettingsSection(
            title: 'Daten',
            icon: Icons.storage_rounded,
            colors: colors,
            children: [
              _SettingsItem(
                icon: Icons.restore_from_trash_rounded,
                title: 'Daten zurücksetzen',
                        subtitle: 'Alle Daten löschen',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                          size: 20,
                          color: colors.onSurface.withOpacity(0.4),
                ),
                onTap: onResetData,
                colors: colors,
              ),
            ],
          ),
          
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final ColorScheme colors;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: colors.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withOpacity(0.5),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outlineVariant.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
          child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final ColorScheme colors;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: colors.onSurface.withOpacity(0.75),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing!,
          ],
        ],
      ),
    );
    
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: colors.primary.withOpacity(0.1),
          highlightColor: colors.primary.withOpacity(0.05),
        child: item,
        ),
      );
    }
    return item;
  }
}

class _Divider extends StatelessWidget {
  final ColorScheme colors;
  
  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: colors.outlineVariant.withOpacity(0.3),
    );
  }
}
