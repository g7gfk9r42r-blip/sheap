/// Profile Screen - Statistiken, Einstellungen
/// Leichte Gamification mit Spar-Statistiken
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/atoms/app_text.dart';
import '../../core/widgets/atoms/app_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data - später aus Backend
    final recipesCooked = 12;
    final weeksActive = 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: AppText(
          'Profil',
          variant: AppTextVariant.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Roman Wolf',
                          variant: AppTextVariant.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppText(
                          'Seit $weeksActive Monaten dabei',
                          variant: AppTextVariant.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Stats Section
            AppText(
              'Statistiken',
              variant: AppTextVariant.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Total Savings Card
            AppCard(
              backgroundColor: AppColors.savingBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.savings_rounded, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.md),
                      AppText(
                        'Gesamt gespart',
                        variant: AppTextVariant.titleMedium,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppText(
                    '100,00 €',
                    variant: AppTextVariant.headlineLarge,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Recipes Cooked Card
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Rezepte gekocht',
                          variant: AppTextVariant.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppText(
                          '$recipesCooked',
                          variant: AppTextVariant.titleLarge,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Settings Section
            AppText(
              'Einstellungen',
              variant: AppTextVariant.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              onTap: () {
                // TODO: Navigate to settings
              },
              child: Row(
                children: [
                  Icon(Icons.settings_rounded, color: AppColors.textPrimary),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: AppText(
                      'Einstellungen',
                      variant: AppTextVariant.bodyLarge,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

