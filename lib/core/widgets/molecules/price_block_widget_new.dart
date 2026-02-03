import 'package:flutter/material.dart';

/// Price Block Widget mit strikethrough für before-Preis
/// Zeigt: before (strikethrough) über now (fett), optional Savings Badge
class PriceBlockWidgetNew extends StatelessWidget {
  const PriceBlockWidgetNew({
    super.key,
    required this.priceBefore,
    required this.priceNow,
    this.savingsPercent,
  });

  final double? priceBefore;
  final double? priceNow;
  final double? savingsPercent;

  bool get hasSavings => priceBefore != null && 
                         priceNow != null && 
                         priceBefore! > priceNow! && 
                         savingsPercent != null && 
                         savingsPercent! > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Wenn nur now vorhanden: nur now normal anzeigen
    if (priceBefore == null || !hasSavings) {
      final displayPrice = priceNow ?? priceBefore;
      if (displayPrice == null) return const SizedBox.shrink();
      
      return Text(
        '${displayPrice.toStringAsFixed(2)} €',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      );
    }

    // hasSavings: before strikethrough, now fett, optional badge
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Before-Preis (strikethrough)
            Text(
              '${priceBefore!.toStringAsFixed(2)} €',
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: colors.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            // Savings Badge (optional)
            if (hasSavings)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Spare ${savingsPercent!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Now-Preis (fett)
        Text(
          '${priceNow!.toStringAsFixed(2)} €',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}
