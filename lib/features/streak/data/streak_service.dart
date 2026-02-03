import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../customer/data/customer_data_store.dart';
import '../../customer/domain/models/customer_app_stats.dart';
import '../../user/data/firestore_user_service.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/firebase/firebase_guard.dart';

class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  String _todayKey(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DateTime _parseDay(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return DateTime(1970);
    return DateTime(
      int.tryParse(parts[0]) ?? 1970,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  /// Updates stats and logs an "app_open" event.
  /// Returns updated stats + whether to show the popup (once per day).
  Future<({CustomerAppStats stats, bool showPopup, String today, String previous})> onAppOpen() async {
    final store = CustomerDataStore.instance;
    final now = DateTime.now();
    final today = _todayKey(now);

    final existing = await store.loadAppStats(); // local cache (fallback)
    final authUser = FirebaseBootstrap.firebaseAvailable
        ? FirebaseGuard.safeFirebase(() => FirebaseAuth.instance.currentUser)
        : null;
    final uid = authUser?.uid ?? '';
    final email = authUser?.email ?? '';

    if (uid.isEmpty) {
      // No session -> keep legacy local behavior to avoid crashes.
      final previous = existing.lastOpenDate;
      final showPopup = previous != today;

      int nextStreak = existing.streakDays;
      if (previous.isEmpty) {
        nextStreak = 1;
      } else if (previous == today) {
        nextStreak = existing.streakDays;
      } else {
        final last = _parseDay(previous);
        final td = _parseDay(today);
        final diff = td.difference(last).inDays;
        if (diff == 1) {
          nextStreak = (existing.streakDays <= 0) ? 1 : (existing.streakDays + 1);
        } else {
          nextStreak = 1;
        }
      }

      final updated = CustomerAppStats(
        streakDays: nextStreak,
        lastOpenDate: today,
        opensCount: existing.opensCount + 1,
        premiumStatus: existing.premiumStatus,
        lastSeenVersion: existing.lastSeenVersion,
        firstRunCompleted: existing.firstRunCompleted,
        lastPopupShownDate: existing.lastPopupShownDate,
      );

      await store.saveAppStats(updated);
      await store.logEvent('app_open', {'streakDays': updated.streakDays, 'today': today});

      if (kDebugMode) {
        debugPrint('🔥 StreakService(no-auth): prev=$previous today=$today streak=${updated.streakDays} popup=$showPopup');
      }

      return (stats: updated, showPopup: showPopup, today: today, previous: previous);
    }

    final fb = await FirestoreUserService.instance.onAppOpen(uid: uid, email: email);
    final previous = fb.previousLastOpenDate;
    final showPopup = previous != today;

    final updated = CustomerAppStats(
      streakDays: fb.streakCount,
      lastOpenDate: fb.lastOpenDate,
      opensCount: fb.appOpenCount,
      premiumStatus: existing.premiumStatus,
      lastSeenVersion: existing.lastSeenVersion,
      firstRunCompleted: existing.firstRunCompleted,
      lastPopupShownDate: existing.lastPopupShownDate,
    );

    await store.saveAppStats(updated);
    await store.logEvent('app_open', {'streakDays': updated.streakDays, 'today': today});

    if (kDebugMode) {
      debugPrint(
        '🔥 StreakService: uid=$uid today=$today lastOpenDate=${fb.lastOpenDate} '
        'streak=${updated.streakDays} opens=${updated.opensCount} storage=${fb.storage} prefs=${fb.preferences} popup=$showPopup',
      );
    }

    return (stats: updated, showPopup: showPopup, today: today, previous: previous);
  }
}


