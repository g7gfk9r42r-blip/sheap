import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseGuard {
  FirebaseGuard._();

  static bool initAttempted = false;
  static Object? initError;

  static bool get firebaseReady => Firebase.apps.isNotEmpty;

  static T? safeFirebase<T>(T Function() fn) {
    if (!firebaseReady) return null;
    try {
      return fn();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ FirebaseGuard.safeFirebase error: $e');
      return null;
    }
  }

  static Future<T?> safeFirebaseAsync<T>(Future<T> Function() fn) async {
    if (!firebaseReady) return null;
    try {
      return await fn();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ FirebaseGuard.safeFirebaseAsync error: $e');
      return null;
    }
  }
}


