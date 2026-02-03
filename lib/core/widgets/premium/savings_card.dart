/// Premium Savings Card Widget
/// Shows daily/weekly savings prominently with animations
import 'package:flutter/material.dart';
import '../../theme/grocify_theme.dart';

class SavingsCard extends StatelessWidget {
  final double amount;
  final String period; // "Heute" or "Diese Woche"
  final double? percentageChange;
  final VoidCallback? onTap;

  const SavingsCard({
    super.key,
    required this.amount,
    this.period = "Heute",
    this.percentageChange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(GrocifyTheme.spaceXXL),
        decoration: BoxDecoration(
          gradient: GrocifyTheme.successGradient,
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusXXL),
          boxShadow: GrocifyTheme.shadowMD,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(GrocifyTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
                  ),
                  child: const Icon(
                    Icons.savings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: GrocifyTheme.spaceLG),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$period gespart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (percentageChange != null) ...[
                        const SizedBox(height: GrocifyTheme.spaceXS),
                        Row(
                          children: [
                            Icon(
                              percentageChange! > 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: GrocifyTheme.spaceXS),
                            Text(
                              '${percentageChange!.abs().toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: GrocifyTheme.spaceXL),
            Text(
              '${amount.toStringAsFixed(2)} €',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

