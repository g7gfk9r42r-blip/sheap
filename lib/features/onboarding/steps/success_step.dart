/// Success Step - Willkommen Screen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';

class SuccessStep extends StatelessWidget {
  final VoidCallback onComplete;

  const SuccessStep({
    super.key,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GrocifyTheme.background,
              GrocifyTheme.background.withOpacity(0.96),
              GrocifyTheme.primary.withOpacity(0.10),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Success Icon
              Container(
                padding: const EdgeInsets.all(GrocifyTheme.spaceXXXL),
                decoration: BoxDecoration(
                  gradient: GrocifyTheme.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: GrocifyTheme.shadowMD,
                ),
                child: const Text('🎉', style: TextStyle(fontSize: 56)),
              ),

              const SizedBox(height: GrocifyTheme.spaceXXL),

              // Card (premium)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(GrocifyTheme.spaceXL),
                decoration: BoxDecoration(
                  color: GrocifyTheme.surface,
                  borderRadius: BorderRadius.circular(GrocifyTheme.radiusXL),
                  border: Border.all(color: GrocifyTheme.border.withOpacity(0.60)),
                  boxShadow: GrocifyTheme.shadowMD,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Du bist startklar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: GrocifyTheme.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: GrocifyTheme.spaceSM),
                    Text(
                      'Willkommen bei sheap — wir zeigen dir jetzt passende Rezepte aus Angeboten.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: GrocifyTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: GrocifyTheme.spaceLG),
                    _Bullet(text: 'Rezepte nach Supermarkt & Woche'),
                    _Bullet(text: 'Bilder werden vorab geladen (schnelleres Scrollen)'),
                    _Bullet(text: 'Wöchentliche Updates kommen automatisch aus dem Server'),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // CTA Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onComplete();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceLG),
                  ),
                  child: const Text(
                    'Starten',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: GrocifyTheme.spaceLG),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: GrocifyTheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                color: GrocifyTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

