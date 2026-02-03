import 'package:flutter/material.dart';

import '../../../core/theme/grocify_theme.dart';

class PremiumPlaceholderScreen extends StatelessWidget {
  const PremiumPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: GrocifyTheme.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Premium entdecken',
          style: TextStyle(color: GrocifyTheme.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: GrocifyTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GrocifyTheme.border.withOpacity(0.65)),
                      boxShadow: GrocifyTheme.shadowMD,
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/Logo Jawoll/logo.png',
                            width: 68,
                            height: 68,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 68, height: 68),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Premium (Placeholder)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: GrocifyTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hier kommt später die Premium-Info. Kein Payment, kein Abo – nur ein Platzhalter-Screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.35, color: GrocifyTheme.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        _BenefitRow(icon: Icons.local_fire_department_rounded, text: 'Mehr Motivation (Streak & Ziele)'),
                        const SizedBox(height: 10),
                        _BenefitRow(icon: Icons.filter_alt_rounded, text: 'Bessere Sortierung nach Preferences'),
                        const SizedBox(height: 10),
                        _BenefitRow(icon: Icons.workspace_premium_rounded, text: 'Zusätzliche Features (coming soon)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: GrocifyTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Zurück', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
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

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitRow({required this.icon, required this.text});

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


