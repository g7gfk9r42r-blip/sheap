// Generated-ish options for this repo.
//
// Normally you generate this via `flutterfire configure`.
// In this repo we keep a concrete version so Firebase can be initialized
// via options-only (independent from GoogleService-Info.plist / google-services.json).
//
// Source of values:
// - android/app/google-services.json
// - macos/Runner/GoogleService-Info.plist (bundleId matched Runner bundle id)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      const webPreviewNoAuth = bool.fromEnvironment('WEB_PREVIEW_NO_AUTH', defaultValue: false);
      if (webPreviewNoAuth) {
        throw UnsupportedError('Firebase disabled (web preview mode).');
      }
      const webLocalAuth = bool.fromEnvironment('WEB_LOCAL_AUTH', defaultValue: false);
      if (webLocalAuth) {
        throw UnsupportedError('Firebase disabled (web local auth mode).');
      }
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Firebase is not configured for $defaultTargetPlatform.');
    }
  }

  static String _requireEnv(String key) {
    final v = (dotenv.env[key] ?? '').trim();
    if (v.isEmpty) {
      throw UnsupportedError('Web Firebase config missing: $key (add it to .env).');
    }
    return v;
  }

  // Web Auth mode (Chrome): requires a Firebase Web app configuration.
  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _requireEnv('FIREBASE_WEB_API_KEY'),
        appId: _requireEnv('FIREBASE_WEB_APP_ID'),
        messagingSenderId: _requireEnv('FIREBASE_WEB_MESSAGING_SENDER_ID'),
        projectId: _requireEnv('FIREBASE_WEB_PROJECT_ID'),
        authDomain: _requireEnv('FIREBASE_WEB_AUTH_DOMAIN'),
      );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB5w-PLuwL6-96K6wYfSoPU3ZqnGjy0G5g',
    appId: '1:277833370605:android:13d1558e3d426ad12475e4',
    messagingSenderId: '277833370605',
    projectId: 'sheap-3e228',
    storageBucket: 'sheap-3e228.firebasestorage.app',
  );

  // Apple platforms (iOS + macOS)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDxHZ6een2DHrc678WreMu03rs-h7VqGGI',
    appId: '1:277833370605:ios:8c988516127b2b042475e4',
    messagingSenderId: '277833370605',
    projectId: 'sheap-3e228',
    storageBucket: 'sheap-3e228.firebasestorage.app',
    iosBundleId: 'com.sheap.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDxHZ6een2DHrc678WreMu03rs-h7VqGGI',
    appId: '1:277833370605:ios:8c988516127b2b042475e4',
    messagingSenderId: '277833370605',
    projectId: 'sheap-3e228',
    storageBucket: 'sheap-3e228.firebasestorage.app',
    iosBundleId: 'com.sheap.app',
  );
}


