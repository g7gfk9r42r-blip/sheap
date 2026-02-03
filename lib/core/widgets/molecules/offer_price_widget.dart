import 'package:flutter/material.dart';
import '../../../data/models/recipe_offer.dart';

/// Widget für kompakte Anzeige eines einzelnen Angebots mit Preis
class OfferPriceWidget extends StatelessWidget {
  final RecipeOfferUsed offer;
  final bool compact; // Kompakt-Modus für Cards

  const OfferPriceWidget({
    super.key,
    required this.offer,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Bestimme Referenzpreis (price_before_eur > uvp_eur)
    final referencePrice = offer.priceBeforeEur ?? offer.uvpEur;
    final hasSavings = referencePrice != null && referencePrice > offer.priceEur;
    final savingsPercent = offer.savingsPercent;

    if (compact) {
      // Kompakt für Cards: nur Preis, optional Strikethrough
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasSavings) ...[
            Text(
              '${referencePrice.toStringAsFixed(2)}€',
              style: theme.textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: colors.onSurface.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '${offer.priceEur.toStringAsFixed(2)}€',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: hasSavings ? colors.primary : colors.onSurface,
              fontSize: 12,
            ),
          ),
          if (hasSavings && savingsPercent != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '-${savingsPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Vollständige Anzeige für Detail-Screen
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + Brand
        Text(
          offer.brand != null ? '${offer.brand} — ${offer.exactName}' : offer.exactName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Unit
        Text(
          offer.unit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        // Preisblock
        Row(
          children: [
            if (hasSavings) ...[
              Text(
                '${referencePrice.toStringAsFixed(2)}€',
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: colors.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${offer.priceEur.toStringAsFixed(2)}€',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: hasSavings ? colors.primary : colors.onSurface,
              ),
            ),
            if (hasSavings && savingsPercent != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '-${savingsPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}