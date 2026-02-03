import 'package:flutter/material.dart';
import '../models/recipe_week.dart';

/// Horizontal scrollbares Carousel für Rezepte-Wochen (Yasuo-Style)
/// Zeigt Hero-Bilder mit Text-Overlay, swipeable mit Dots-Indicator
class RecipeWeekCarousel extends StatefulWidget {
  const RecipeWeekCarousel({
    super.key,
    required this.weeks,
    this.onWeekTap,
    this.height = 280,
  });

  final List<RecipeWeek> weeks;
  final ValueChanged<RecipeWeek>? onWeekTap;
  final double height;

  @override
  State<RecipeWeekCarousel> createState() => _RecipeWeekCarouselState();
}

class _RecipeWeekCarouselState extends State<RecipeWeekCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.weeks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.weeks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _WeekCard(
                  week: widget.weeks[index],
                  onTap: widget.onWeekTap != null
                      ? () => widget.onWeekTap!(widget.weeks[index])
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Dots Indicator
        _DotsIndicator(
          currentIndex: _currentPage,
          itemCount: widget.weeks.length,
        ),
      ],
    );
  }
}

/// Einzelne Week-Card mit Hero-Bild und Text-Overlay
class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    this.onTap,
  });

  final RecipeWeek week;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero Image Background (Gradient mit Emoji als Fallback)
              _buildBackground(colors),
              
              // Gradient Overlay (dunkler unten für Text-Lesbarkeit)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              
              // Text Content (unten)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Week Number
                    Text(
                      week.weekNumber,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Recipe Count
                    Text(
                      '${week.recipeCount} Rezepte',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (week.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        week.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(ColorScheme colors) {
    // Versuche Image-URL, sonst Gradient mit Emoji
    if (week.imageUrl.startsWith('http')) {
      return Image.network(
        week.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientBackground(colors),
      );
    } else {
      return _buildGradientBackground(colors);
    }
  }

  Widget _buildGradientBackground(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withOpacity(0.6),
            colors.secondaryContainer.withOpacity(0.4),
            colors.tertiaryContainer.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          week.imageUrl, // Emoji als Fallback
          style: const TextStyle(fontSize: 120),
        ),
      ),
    );
  }
}

/// Dots Indicator für PageView
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.currentIndex,
    required this.itemCount,
  });

  final int currentIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => Container(
          width: currentIndex == index ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: currentIndex == index
                ? colors.primary
                : colors.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
