import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/grocify_theme.dart';

class PremiumPromoDialog extends StatelessWidget {
  final VoidCallback onLater;
  final VoidCallback onDiscover;

  const PremiumPromoDialog({
    super.key,
    required this.onLater,
    required this.onDiscover,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.55)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/Logo Jawoll/logo.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 42, height: 42),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Premium entdecken',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: GrocifyTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Hol mehr aus sheap raus: bessere Sortierung, mehr Motivation und neue Features.',
                    style: TextStyle(fontSize: 13, height: 1.35, color: GrocifyTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  _Point(icon: Icons.filter_alt_rounded, text: 'Preferences & Ranking (coming soon)'),
                  const SizedBox(height: 10),
                  _Point(icon: Icons.local_fire_department_rounded, text: 'Streak & Motivation'),
                  const SizedBox(height: 10),
                  _Point(icon: Icons.workspace_premium_rounded, text: 'Premium Features'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onLater,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: GrocifyTheme.border.withOpacity(0.9)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Später', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: onDiscover,
                          style: FilledButton.styleFrom(
                            backgroundColor: GrocifyTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Premium entdecken', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
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

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: GrocifyTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GrocifyTheme.border.withOpacity(0.35)),
          ),
          child: Icon(icon, color: GrocifyTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GrocifyTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}


