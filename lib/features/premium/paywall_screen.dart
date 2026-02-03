import 'package:flutter/material.dart';
import '../../core/theme/grocify_theme.dart';
import 'premium_service.dart';
import '../auth/data/auth_service_local.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: GrocifyTheme.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Premium',
          style: TextStyle(
            color: GrocifyTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: GrocifyTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Premium',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GrocifyTheme.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '6,99 € / Monat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GrocifyTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _buildBenefitItem(icon: Icons.filter_alt_rounded, text: 'Preferences & Ranking (z.B. vegetarisch zuerst)'),
              const SizedBox(height: 12),
              _buildBenefitItem(icon: Icons.local_fire_department_rounded, text: 'Streak & Motivation'),
              const SizedBox(height: 12),
              _buildBenefitItem(icon: Icons.workspace_premium_rounded, text: 'Premium Features (MVP)'),
              const Spacer(),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: () async {
                    final user = await AuthServiceLocal.instance.getCurrentUser();
                    if (user == null) return;
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaymentMethodScreen(uid: user.uid),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: GrocifyTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Weiter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(GrocifyTheme.spaceSM),
          decoration: BoxDecoration(
            color: GrocifyTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusSM),
          ),
          child: Icon(icon, color: GrocifyTheme.primary, size: 20),
        ),
        const SizedBox(width: GrocifyTheme.spaceMD),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: GrocifyTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class PaymentMethodScreen extends StatefulWidget {
  final String uid;
  const PaymentMethodScreen({super.key, required this.uid});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _method = 'apple_pay';

  @override
  Widget build(BuildContext context) {
    final svc = PremiumService.instance;
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: const Text(
          'Zahlungsart',
          style: TextStyle(color: GrocifyTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _methodTile('Apple Pay', 'apple_pay'),
              _methodTile('Google Pay', 'google_pay'),
              _methodTile('PayPal', 'paypal'),
              _methodTile('Kreditkarte', 'credit_card'),
              _methodTile('Klarna', 'klarna'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: svc.isLoading
                      ? null
                      : () async {
                          await svc.purchaseMonthly(uid: widget.uid, paymentMethod: _method);
                          if (!context.mounted) return;
                          if (svc.premiumActive) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const _PremiumSuccessScreen()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(svc.error ?? 'Purchase fehlgeschlagen')),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: GrocifyTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: svc.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Jetzt bezahlen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile(String title, String value) {
    final selected = _method == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _method = value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? GrocifyTheme.primary.withOpacity(0.08) : GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? GrocifyTheme.primary : GrocifyTheme.border.withOpacity(0.6), width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? GrocifyTheme.primary : GrocifyTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GrocifyTheme.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumSuccessScreen extends StatelessWidget {
  const _PremiumSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: GrocifyTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Premium aktiv',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: GrocifyTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Danke! Dein Premium ist jetzt aktiv.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GrocifyTheme.textSecondary),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    style: FilledButton.styleFrom(
                      backgroundColor: GrocifyTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Zur App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

