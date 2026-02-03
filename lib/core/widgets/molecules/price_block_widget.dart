/// Price Block Widget
/// Zeigt Standardpreis und optional Loyalty-Preis klar getrennt an
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class PriceBlockWidget extends StatelessWidget {
  final double? standardPrice;
  final double? loyaltyPrice;
  final String? loyaltyCondition;
  final String? unit;
  final double? originalPrice; // UVP/Referenzpreis
  final bool showUnit;

  const PriceBlockWidget({
    super.key,
    this.standardPrice,
    this.loyaltyPrice,
    this.loyaltyCondition,
    this.unit,
    this.originalPrice,
    this.showUnit = true,
  });

  /// Prüft ob nur Loyalty-Preis vorhanden ist
  bool get hasOnlyLoyaltyPrice => loyaltyPrice != null && standardPrice == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Standardpreis (groß, wenn vorhanden)
        if (standardPrice != null && standardPrice! > 0) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${standardPrice!.toStringAsFixed(2)} €',
                style: AppTypography.titleLarge(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (showUnit && unit != null && unit!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '/ $unit',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Loyalty-Preis darunter (kleiner)
          if (loyaltyPrice != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.card_membership_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${loyaltyCondition ?? "Mit Karte"}: ${loyaltyPrice!.toStringAsFixed(2)} €',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          // UVP/Referenzpreis (klein, grau)
          if (originalPrice != null && originalPrice! > standardPrice!) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'statt ${originalPrice!.toStringAsFixed(2)} €',
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.textTertiary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ] else if (hasOnlyLoyaltyPrice) ...[
          // Nur Loyalty-Preis vorhanden
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${loyaltyCondition ?? "Mit Karte"}: ${loyaltyPrice!.toStringAsFixed(2)} €',
                    style: AppTypography.titleLarge(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (showUnit && unit != null && unit!.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '/ $unit',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Standardpreis unbekannt',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ] else ...[
          // Kein Preis vorhanden
          Text(
            'Preis nicht verfügbar',
            style: AppTypography.bodyMedium(context).copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

