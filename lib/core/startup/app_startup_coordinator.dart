import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/auth/data/auth_service_local.dart';
import '../../features/customer/data/customer_data_store.dart';
import '../../features/customer/domain/models/customer_profile.dart';
import '../../features/streak/data/streak_service.dart';
import '../../features/streak/presentation/welcome_streak_sheet.dart';
import '../../features/premium/presentation/premium_placeholder_screen.dart';
import '../../features/premium/presentation/premium_promo_dialog.dart';

class AppStartupCoordinator {
  AppStartupCoordinator._();
  static final AppStartupCoordinator instance = AppStartupCoordinator._();

  bool _ranThisLaunch = false;

  Future<void> runIfNeeded(BuildContext context) async {
    if (_ranThisLaunch) return;
    _ranThisLaunch = true;

    final user = await AuthServiceLocal.instance.getCurrentUser();
    if (user == null) {
      if (kDebugMode) debugPrint('🧭 StartupCoordinator: no session -> no popup');
      return;
    }

    // Ensure customer_profile.json exists & is up-to-date for UI
    final store = CustomerDataStore.instance;
    CustomerProfile? profile = await store.loadProfile();
    if (profile == null) {
      // Fallback build from local auth user
      final now = DateTime.now().toUtc().toIso8601String();
      profile = CustomerProfile(
        userId: user.uid,
        email: user.email,
        name: user.profile.displayName.isNotEmpty ? user.profile.displayName : null,
        createdAt: now,
        lastLoginAt: now,
        consentAcceptedAt: now,
      );
      await store.saveProfile(profile);
    }

    final openResult = await StreakService.instance.onAppOpen();
    if (!context.mounted) return;
    debugPrint(
      '🪟 Popups: start uid=${user.uid} appOpenCount=${openResult.stats.opensCount} '
      'streak=${openResult.stats.streakDays} (streak popup: YES)',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => WelcomeStreakSheet(
        name: profile?.name,
        streakDays: openResult.stats.streakDays,
      ),
    );

    if (!context.mounted) return;

    // Premium promo popup: every 3rd app open.
    final count = openResult.stats.opensCount;
    final premiumDue = count > 0 && (count % 3 == 0);
    debugPrint('🪟 Popups: premiumDue=${premiumDue ? "YES" : "NO"} (appOpenCount=$count)');
    if (!premiumDue) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PremiumPromoDialog(
        onLater: () => Navigator.of(context).pop(),
        onDiscover: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PremiumPlaceholderScreen()),
          );
        },
      ),
    );
  }
}


