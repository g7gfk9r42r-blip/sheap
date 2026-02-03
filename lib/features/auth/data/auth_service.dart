import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_bootstrap.dart';

/// Thin firebase_auth wrapper for Email/Password flows.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Stream<User?> userChanges() => FirebaseAuth.instance.userChanges();
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<UserCredential> signUp({required String email, required String password}) async {
    _ensureFirebase();
    final e = email.trim();
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: e, password: password);
    // Optional but usually desired: send verification after signup
    try {
      await cred.user?.sendEmailVerification();
    } catch (e) {
      if (kDebugMode) debugPrint('ℹ️ sendEmailVerification failed (ignored): $e');
    }
    return cred;
  }

  Future<UserCredential> signIn({required String email, required String password}) async {
    _ensureFirebase();
    final e = email.trim();
    return FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: password);
  }

  Future<void> signOut() async {
    if (!FirebaseBootstrap.firebaseAvailable) return;
    await FirebaseAuth.instance.signOut();
  }

  static String mapUiError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Bitte gib eine gültige E‑Mail-Adresse ein.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E‑Mail oder Passwort ist falsch.';
        case 'email-already-in-use':
          return 'Diese E‑Mail ist bereits registriert.';
        case 'weak-password':
          return 'Passwort ist zu schwach (mindestens 8 Zeichen).';
        case 'too-many-requests':
          return 'Zu viele Versuche. Bitte warte kurz und versuche es erneut.';
        case 'network-request-failed':
          return 'Netzwerkfehler. Bitte prüfe deine Verbindung.';
      }
      final msg = (error.message ?? '').trim();
      return msg.isNotEmpty ? msg : 'Anmeldung fehlgeschlagen.';
    }
    return 'Anmeldung fehlgeschlagen.';
  }

  void _ensureFirebase() {
    if (!FirebaseBootstrap.firebaseAvailable) {
      throw StateError('Firebase init failed (firebaseAvailable=false).');
    }
  }
}


