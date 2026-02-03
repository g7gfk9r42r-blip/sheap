import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';
import '../../firebase_options.dart';

class FirebaseStartupDiagnostics {
  FirebaseStartupDiagnostics._();

  static bool _printed = false;

  static Future<void> printOnce() async {
    if (!kDebugMode) return;
    if (_printed) return;
    _printed = true;

    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('=== FIREBASE DIAGNOSTICS ===');
    debugPrint('════════════════════════════════════════════════════════════');

    debugPrint('Platform: kIsWeb=$kIsWeb target=$defaultTargetPlatform');

    // Options-only init status
    debugPrint('Firebase init: available=${FirebaseBootstrap.firebaseAvailable}');
    if (!FirebaseBootstrap.firebaseAvailable) {
      debugPrint('Firebase init error: ${FirebaseBootstrap.lastFirebaseInitError ?? "unknown"}');
      if (FirebaseBootstrap.lastFirebaseInitStack != null) {
        debugPrint('Stacktrace:\n${FirebaseBootstrap.lastFirebaseInitStack}');
      }
    }

    // Runtime diagnostics:
    // On Web, touching firebase_core APIs when init failed can throw JS interop type errors.
    if (FirebaseBootstrap.firebaseAvailable) {
      try {
        debugPrint('Firebase.apps.length: ${Firebase.apps.length}');
        final app = Firebase.app();
        debugPrint('Firebase.app().options.projectId: ${app.options.projectId}');
        debugPrint('Firebase.app().options.googleAppID: ${app.options.appId}');
        final apiKey = app.options.apiKey;
        final apiKeyPrefix = apiKey.length >= 6 ? apiKey.substring(0, 6) : apiKey;
        debugPrint('Firebase.app().options.apiKey(prefix): ${apiKeyPrefix}******');
        debugPrint('FirebaseAuth.instance.currentUser?.uid: ${FirebaseAuth.instance.currentUser?.uid ?? "null"}');
      } catch (e) {
        debugPrint('Diagnostics: Firebase runtime check failed ($e)');
      }
    } else {
      debugPrint('Diagnostics: skipped (firebase unavailable)');
    }

    // Options sanity (debug only)
    try {
      final o = DefaultFirebaseOptions.currentPlatform;
      debugPrint('DefaultFirebaseOptions.currentPlatform: projectId=${o.projectId} appId=${o.appId} senderId=${o.messagingSenderId}');
    } catch (e) {
      debugPrint('DefaultFirebaseOptions.currentPlatform: UNAVAILABLE ($e)');
    }

    debugPrint('════════════════════════════════════════════════════════════');
  }
}


