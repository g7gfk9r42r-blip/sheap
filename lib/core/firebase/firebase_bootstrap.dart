import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool firebaseAvailable = false;
  static String? lastFirebaseInitError;
  static Object? lastFirebaseInitException;
  static StackTrace? lastFirebaseInitStack;
  static bool optionsFilePresent = true; // compiled in (may still be a stub)
  static bool optionsUsable = false;
  static String? optionsError;

  static bool _loggedOnce = false;

  /// Single source of truth for Firebase init.
  /// Requirements:
  /// - ALWAYS initialize via `DefaultFirebaseOptions.currentPlatform`
  /// - NEVER call `Firebase.initializeApp()` without options
  /// - MUST NOT crash app if init fails
  static Future<void> initFirebase() async {
    // Reset state for a fresh startup (hot restart)
    firebaseAvailable = false;
    lastFirebaseInitError = null;
    lastFirebaseInitException = null;
    lastFirebaseInitStack = null;
    optionsUsable = false;
    optionsError = null;

    // Release/Test builds can disable Firebase entirely (no login required).
    const disableFirebase = bool.fromEnvironment('DISABLE_FIREBASE', defaultValue: false);
    // Safety: avoid accidentally shipping a release build with Firebase disabled.
    // If you truly need a no-login release build, use a dedicated flavor.
    final effectiveDisableFirebase = disableFirebase && !kReleaseMode;
    if (disableFirebase && kReleaseMode && !_loggedOnce) {
      _loggedOnce = true;
      debugPrint('⚠️ Firebase DISABLE_FIREBASE=true ignored in RELEASE (safety).');
    }
    if (effectiveDisableFirebase) {
      if (!_loggedOnce) {
        _loggedOnce = true;
        debugPrint('ℹ️ Firebase disabled via --dart-define=DISABLE_FIREBASE=true');
      }
      firebaseAvailable = false;
      return;
    }

    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      optionsUsable = true;

      await Firebase.initializeApp(options: options);
      firebaseAvailable = Firebase.apps.isNotEmpty;
      lastFirebaseInitError = null;
      lastFirebaseInitException = null;
      lastFirebaseInitStack = null;

      if (!_loggedOnce) {
        _loggedOnce = true;
        debugPrint('✅ Firebase init OK (options-only)');
      }
    } catch (e, st) {
      firebaseAvailable = false;
      lastFirebaseInitException = e;
      lastFirebaseInitStack = st;
      lastFirebaseInitError = e.toString();
      optionsUsable = false;
      optionsError = e.toString();

      if (!_loggedOnce) {
        _loggedOnce = true;
        debugPrint('❌ Firebase init FAILED (options-only): $e');
        debugPrint('$st');
        debugPrint('ℹ️ App continues, but Auth will show "Firebase init failed".');
      }
    }
  }
}


