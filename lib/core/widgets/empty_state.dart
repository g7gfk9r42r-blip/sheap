/// EmptyState
/// Leere Zustände mit Illustration, Text und CTA
import 'package:flutter/material.dart';
import '../theme/grocify_theme.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;
  final Widget? customContent;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCtaTap,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GrocifyTheme.screenPaddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: GrocifyTheme.spaceXXL),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: GrocifyTheme.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: GrocifyTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (customContent != null) ...[
              const SizedBox(height: GrocifyTheme.spaceXXL),
              customContent!,
            ],
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: GrocifyTheme.spaceXXL),
              PrimaryButton(
                label: ctaLabel!,
                onPressed: onCtaTap,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

