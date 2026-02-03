/// Quick Preferences Step - Ziel & Ernährung (ohne Gewicht/Water)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';
import '../models/user_profile_local.dart';

class QuickPrefsStep extends StatefulWidget {
  final UserProfileLocal profile;
  final Function(UserProfileLocal) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const QuickPrefsStep({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<QuickPrefsStep> createState() => _QuickPrefsStepState();
}

class _QuickPrefsStepState extends State<QuickPrefsStep> {
  GoalType? _goal;
  bool _vegetarian = false;
  bool _vegan = false;

  @override
  void initState() {
    super.initState();
    _goal = widget.profile.goalType;
    _vegetarian = widget.profile.dietPreferences.contains(DietPreference.vegetarian);
    _vegan = widget.profile.dietPreferences.contains(DietPreference.vegan);
  }

  void _update() {
    final prefs = <DietPreference>{};
    if (_vegetarian) prefs.add(DietPreference.vegetarian);
    if (_vegan) prefs.add(DietPreference.vegan);
    widget.onUpdate(
      widget.profile.copyWith(
        goalType: _goal,
        dietPreferences: prefs,
      ),
    );
  }

  void _setDiet({required bool vegetarian, required bool vegan}) {
    setState(() {
      _vegetarian = vegetarian;
      _vegan = vegan;
    });
    _update();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: GrocifyTheme.spaceXL),
            const Text(
              'Kurz personalisieren ✨',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceSM),
            Text(
              'Wie sollen deine ersten Rezepte aussehen? Du kannst alles später jederzeit ändern.',
              style: TextStyle(
                fontSize: 16,
                color: GrocifyTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceXXL),

            // Filter-style sections (like recipe diet filter chips)
            _FilterSection(
              title: 'Ziel (optional)',
              subtitle: 'Wähle, was dir wichtig ist.',
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    final items = const [
                      ('Abnehmen', '📉', Color(0xFF3B82F6), GoalType.loseWeight),
                      ('Halten', '➖', Color(0xFF10B981), GoalType.maintainWeight),
                      ('Zunehmen', '📈', Color(0xFFF59E0B), GoalType.gainWeight),
                    ];
                    final it = items[idx];
                    final label = it.$1;
                    final emoji = it.$2;
                    final color = it.$3;
                    final value = it.$4;
                    final isSelected = _goal == value;
                    return _OnboardingFilterChip(
                      label: label,
                      emoji: emoji,
                      chipColor: color,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _goal = isSelected ? null : value;
                        });
                        _update();
                      },
                      colors: colors,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            _FilterSection(
              title: 'Ernährung',
              subtitle: 'Damit die ersten Rezepte direkt passen.',
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    final items = const [
                      ('Normal', '🍽️', Color(0xFF64748B), 0),
                      ('Vegetarisch', '🥕', Color(0xFFF59E0B), 1),
                      ('Vegan', '🌱', Color(0xFF059669), 2),
                    ];
                    final it = items[idx];
                    final label = it.$1;
                    final emoji = it.$2;
                    final color = it.$3;
                    final mode = it.$4;
                    final isSelected = switch (mode) {
                      0 => !_vegetarian && !_vegan,
                      1 => _vegetarian && !_vegan,
                      _ => _vegan,
                    };
                    return _OnboardingFilterChip(
                      label: label,
                      emoji: emoji,
                      chipColor: color,
                      isSelected: isSelected,
                      onTap: () {
                        if (mode == 0) _setDiet(vegetarian: false, vegan: false);
                        if (mode == 1) _setDiet(vegetarian: true, vegan: false);
                        if (mode == 2) _setDiet(vegetarian: false, vegan: true);
                      },
                      colors: colors,
                    );
                  },
                ),
              ),
            ),

            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onSkip();
                    },
                    child: const Text('Später'),
                  ),
                ),
                const SizedBox(width: GrocifyTheme.spaceMD),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      _update();
                      HapticFeedback.lightImpact();
                      widget.onNext();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceLG),
                    ),
                    child: const Text('Weiter 🚀'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GrocifyTheme.spaceLG),
          ],
        ),
      ),
    );
  }

}

class _FilterSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _FilterSection({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.25)),
        boxShadow: GrocifyTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: GrocifyTheme.textSecondary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OnboardingFilterChip extends StatelessWidget {
  const _OnboardingFilterChip({
    required this.label,
    required this.emoji,
    required this.chipColor,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final String emoji;
  final Color chipColor;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [chipColor, chipColor.withOpacity(0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? chipColor : colors.outlineVariant.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? Colors.white : colors.onSurface.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


