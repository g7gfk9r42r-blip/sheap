/// Upgrade Bar Widget - Shows premium upgrade prompt for free users
import 'package:flutter/material.dart';
import '../../../core/theme/grocify_theme.dart';
import '../premium_service.dart';

class UpgradeBar extends StatelessWidget {
  final String? customMessage;
  final VoidCallback? onUpgrade;

  const UpgradeBar({
    super.key,
    this.customMessage,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final premiumService = PremiumService.instance;

    // Only show for free users
    if (premiumService.premiumActive) {
      return const SizedBox.shrink();
    }

    // Coming soon overlay (requested)
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(GrocifyTheme.spaceMD),
          padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
          decoration: BoxDecoration(
            gradient: GrocifyTheme.primaryGradient,
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
            boxShadow: GrocifyTheme.shadowMD,
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 24),
              const SizedBox(width: GrocifyTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Premium',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customMessage ?? 'Erweiterte Features (Coming soon)',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GrocifyTheme.spaceMD),
              FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.85),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: GrocifyTheme.spaceLG,
                    vertical: GrocifyTheme.spaceSM,
                  ),
                ),
                child: const Text('Coming soon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
            child: Container(color: Colors.grey.withOpacity(0.18)),
          ),
        ),
      ],
    );
  }
}

