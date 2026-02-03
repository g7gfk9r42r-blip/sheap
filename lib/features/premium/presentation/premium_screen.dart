import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/grocify_theme.dart';
import '../premium_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _svc = PremiumService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChanged);
  }

  @override
  void dispose() {
    _svc.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: const Text('Premium', style: TextStyle(color: GrocifyTheme.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GrocifyTheme.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: GrocifyTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GrocifyTheme.border.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('6,99 € / Monat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text('Apple In‑App Purchase (StoreKit)', style: TextStyle(color: GrocifyTheme.textSecondary)),
                    SizedBox(height: 10),
                    Text('Coming soon – Feature ist vorbereitet, aber noch nicht aktiv.'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_svc.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GrocifyTheme.error.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GrocifyTheme.error.withOpacity(0.25)),
                  ),
                  child: Text(_svc.error!, style: const TextStyle(color: GrocifyTheme.error, fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.apple_rounded),
                  label: const Text('Coming soon', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (kDebugMode)
                Text(
                  'Debug: premiumActive=${_svc.premiumActive}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: GrocifyTheme.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


