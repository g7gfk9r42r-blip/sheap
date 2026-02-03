import 'package:firebase_core/firebase_core.dart';
import '../../../firebase_options.dart';

/// Small bootstrap helper so the app can log init status and show a clear UI
/// if Firebase isn't configured (missing google-services.json / GoogleService-Info.plist).
class FirebaseInit {
  FirebaseInit._();

  static bool _initialized = false;
  static Object? _lastError;

  static bool get initialized => _initialized;
  static Object? get lastError => _lastError;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      // Single init path: options-only (same as main bootstrap).
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _initialized = true;
      _lastError = null;
    } catch (e) {
      _initialized = false;
      _lastError = e;
      rethrow;
    }
  }
}


