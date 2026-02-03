/// Supermarket Step - Supermarkt-Präferenz
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';
import '../models/user_profile_local.dart';

class SupermarketStep extends StatefulWidget {
  final UserProfileLocal profile;
  final Function(UserProfileLocal) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const SupermarketStep({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<SupermarketStep> createState() => _SupermarketStepState();
}

class _SupermarketStepState extends State<SupermarketStep> {
  final Set<String> _selectedSupermarkets = {};

  final List<Map<String, String>> _supermarkets = const [
    {'name': 'Rewe', 'retailer': 'REWE'},
    {'name': 'Lidl', 'retailer': 'LIDL'},
    {'name': 'Aldi Süd', 'retailer': 'ALDI SÜD'},
    {'name': 'Aldi Nord', 'retailer': 'ALDI NORD'},
    {'name': 'Kaufland', 'retailer': 'KAUFLAND'},
    {'name': 'Penny', 'retailer': 'PENNY'},
    {'name': 'Netto', 'retailer': 'NETTO'},
    {'name': 'Norma', 'retailer': 'NORMA'},
    {'name': 'Tegut', 'retailer': 'TEGUT'},
    {'name': 'Marktkauf', 'retailer': 'MARKTKAUF'},
    {'name': 'Nahkauf', 'retailer': 'NAHKAUF'},
    {'name': 'Denns', 'retailer': 'DENNS'},
    {'name': 'Biomarkt', 'retailer': 'BIOMARKT'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedSupermarkets
      ..clear()
      ..addAll(widget.profile.favoriteSupermarkets);
    final legacy = (widget.profile.preferredSupermarket ?? '').trim();
    if (legacy.isNotEmpty) _selectedSupermarkets.add(legacy);
  }

  void _updateProfile() {
    widget.onUpdate(
      widget.profile.copyWith(
        favoriteSupermarkets: _selectedSupermarkets.toList()..sort(),
        preferredSupermarket: _selectedSupermarkets.isEmpty ? null : (_selectedSupermarkets.first),
      ),
    );
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
            
            // Header
            const Text(
              'Dein Lieblings‑Supermarkt 🛒',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceSM),
            Text(
              'Wähle deinen Favoriten – dann findest du schneller die passenden Angebote.',
              style: TextStyle(
                fontSize: 16,
                color: GrocifyTheme.textSecondary,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceXXL),
            
            // Supermarket Grid (2 Cards pro Reihe, full width)
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: GrocifyTheme.spaceMD,
                  mainAxisSpacing: GrocifyTheme.spaceMD,
                  childAspectRatio: 1.9,
                ),
                itemCount: _supermarkets.length,
                itemBuilder: (context, index) {
                  final market = _supermarkets[index];
                  final retailer = market['retailer']!;
                  final isSelected = _selectedSupermarkets.contains(retailer);
                  final accent = _marketColor(retailer);
                  final emoji = _marketEmoji(retailer);
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSupermarkets.remove(retailer);
                        } else {
                          _selectedSupermarkets.add(retailer);
                        }
                      });
                      _updateProfile();
                      HapticFeedback.selectionClick();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [accent, accent.withOpacity(0.78)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? accent : colors.outlineVariant.withOpacity(0.25),
                          width: isSelected ? 1.6 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accent.withOpacity(0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : GrocifyTheme.shadowSM,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  market['name']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? Colors.white : GrocifyTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isSelected ? 'Favorit ✓' : 'Antippen zum Auswählen',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white.withOpacity(0.92) : GrocifyTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceLG),
            
            // Buttons
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
                      _updateProfile();
                      HapticFeedback.lightImpact();
                      widget.onNext();
                    },
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

  String _marketEmoji(String retailer) {
    switch (retailer) {
      case 'REWE':
        return '🟥';
      case 'LIDL':
        return '🟦';
      case 'ALDI NORD':
      case 'ALDI SÜD':
        return '🟦';
      case 'KAUFLAND':
        return '🛒';
      case 'PENNY':
        return '🟠';
      case 'NETTO':
        return '⚫';
      case 'NORMA':
        return '🟨';
      case 'TEGUT':
        return '🟩';
      case 'DENNS':
      case 'BIOMARKT':
        return '🌿';
      case 'NAHKAUF':
        return '🏪';
      default:
        return '🛍️';
    }
  }

  Color _marketColor(String retailer) {
    switch (retailer) {
      case 'REWE':
        return const Color(0xFFEF4444); // Red
      case 'LIDL':
        return const Color(0xFF2563EB); // Blue
      case 'ALDI NORD':
      case 'ALDI SÜD':
        return const Color(0xFF1D4ED8); // Deep blue
      case 'KAUFLAND':
        return const Color(0xFFDC2626); // Red
      case 'PENNY':
        return const Color(0xFFF97316); // Orange
      case 'NETTO':
        return const Color(0xFF111827); // Near black
      case 'NORMA':
        return const Color(0xFFF59E0B); // Amber
      case 'TEGUT':
        return const Color(0xFF10B981); // Emerald
      case 'DENNS':
      case 'BIOMARKT':
        return const Color(0xFF059669); // Green
      case 'NAHKAUF':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return GrocifyTheme.primary;
    }
  }
}

