import 'package:flutter/foundation.dart';

/// Central privacy/persistence switches.
///
/// Important:
/// - This is NOT about "selling data". Personal data selling requires explicit legal basis and consent.
/// - These switches help minimize local persistence and gate optional telemetry.
class AppPrivacyConfig {
  AppPrivacyConfig._();

  /// If false, we do not persist personal onboarding/profile data on-device.
  /// Default: true (local-first).
  static const bool persistUserProfileLocal =
      bool.fromEnvironment('PERSIST_USER_PROFILE_LOCAL', defaultValue: true);

  /// If false, favorites are session-only (not stored on-device).
  /// Default: true (local-first).
  static const bool persistFavoritesLocal =
      bool.fromEnvironment('PERSIST_FAVORITES_LOCAL', defaultValue: true);

  /// If false, recipe HTTP cache is not persisted (always fetch remote, fallback to assets).
  /// Default: true (stability/performance) – recipe JSON is not personal data.
  static const bool persistRecipeCacheLocal =
      bool.fromEnvironment('PERSIST_RECIPE_CACHE_LOCAL', defaultValue: true);

  /// If true, allow telemetry only when user explicitly opted-in.
  /// Default: true.
  static const bool telemetryRequiresOptIn =
      bool.fromEnvironment('TELEMETRY_OPT_IN_REQUIRED', defaultValue: true);

  static void debugPrintConfigOnce() {
    if (!kDebugMode) return;
    debugPrint(
      '🔒 AppPrivacyConfig: '
      'persistUserProfileLocal=$persistUserProfileLocal '
      'persistFavoritesLocal=$persistFavoritesLocal '
      'persistRecipeCacheLocal=$persistRecipeCacheLocal '
      'telemetryRequiresOptIn=$telemetryRequiresOptIn',
    );
  }
}


