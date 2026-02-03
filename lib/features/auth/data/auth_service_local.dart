import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/customer_storage.dart';
import '../../../core/firebase/firebase_guard.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import 'models/user_account.dart';
import '../../onboarding/onboarding_repository.dart';
import '../../onboarding/models/user_profile_local.dart';
import '../../customer/data/customer_data_store.dart';
import '../../customer/domain/models/customer_app_stats.dart';
import '../../customer/domain/models/customer_preferences.dart';
import '../../customer/domain/models/customer_profile.dart';
// NOTE: We intentionally do NOT write any user data to Firestore for now.

class AuthServiceLocal {
  static bool _loggedAuthUnavailable = false;

  /// Web-only local auth session (used when Firebase is disabled on web).
  /// This is the "source of truth" for AuthGate in web-local mode.
  static final ValueNotifier<UserAccount?> webLocalUser = ValueNotifier<UserAccount?>(null);

  /// Safe access to the underlying Firebase user (never throws).
  User? getCurrentUserSafe() {
    if (!FirebaseBootstrap.firebaseAvailable) return null;
    final u = FirebaseGuard.safeFirebase(() => FirebaseAuth.instance.currentUser);
    if (u == null && !_loggedAuthUnavailable) {
      // Only log once to avoid spam during startup.
      _loggedAuthUnavailable = true;
      if (kDebugMode) debugPrint('ℹ️ Auth session available: false (firebase ready but no user)');
    }
    return u;
  }
  AuthServiceLocal._();
  static final AuthServiceLocal instance = AuthServiceLocal._();
  
  final _storage = CustomerStorage.instance;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool get _useWebLocalAuth => kIsWeb && !FirebaseBootstrap.firebaseAvailable;

  void _setWebLocalUser(UserAccount? user) {
    if (!_useWebLocalAuth) return;
    webLocalUser.value = user;
  }

  String _localUidForEmail(String email) {
    final e = email.trim().toLowerCase();
    final b64 = base64Url.encode(utf8.encode(e));
    return 'web_$b64';
  }

  String _pwSaltKey(String uid) => 'local_auth_salt_$uid';
  String _pwHashKey(String uid) => 'local_auth_hash_$uid';

  String _hashPassword(String salt, String password) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  String _randomSalt() {
    try {
      final r = Random.secure();
      return List<int>.generate(16, (_) => r.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (_) {
      // Web fallback (still fine for local preview auth)
      final n = DateTime.now().microsecondsSinceEpoch;
      return sha256.convert(utf8.encode('$n')).toString().substring(0, 32);
    }
  }

  Future<void> _writeSession({required String uid, required String email}) async {
    await _storage.writeJson(CustomerPaths.currentSessionFile(), {
      'uid': uid,
      'email': email,
      'logged_in_at': DateTime.now().toUtc().toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();
    // Spec keys
    await prefs.setString('session_user_id', uid);
    await prefs.setString('session_email', email);
    await prefs.setBool('session_is_logged_in', true);
    // Back-compat keys
    await prefs.setString('session_uid', uid);
    await prefs.setString('session_logged_in_at', DateTime.now().toUtc().toIso8601String());
  }

  Future<void> _clearSession() async {
    await _storage.delete(CustomerPaths.currentSessionFile());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    await prefs.remove('session_is_logged_in');
    await prefs.remove('session_uid');
    await prefs.remove('session_email');
    await prefs.remove('session_logged_in_at');
  }

  Future<void> logout() async {
    if (FirebaseBootstrap.firebaseAvailable) {
      await FirebaseGuard.safeFirebaseAsync(() => FirebaseAuth.instance.signOut());
    }
    await _clearSession();
    _setWebLocalUser(null);
    await CustomerDataStore.instance.logEvent('logout', {});
    if (kDebugMode) debugPrint('✅ Auth logout: session cleared');
  }

  String _mapAuthError(FirebaseAuthException e) {
    // Keep messages short, German, user-facing.
    final msg = (e.message ?? '');
    if (msg.contains('CONFIGURATION_NOT_FOUND') || msg.contains('FIRAuthErrorDomain') || msg.contains('17999')) {
      return 'iOS Firebase Setup fehlerhaft (CONFIGURATION_NOT_FOUND). '
          'Fix: Stelle sicher, dass die iOS App im Firebase Projekt zur Bundle ID passt und `lib/firebase_options.dart` korrekt ist '
          '(am besten `flutterfire configure` erneut ausführen).';
    }
    switch (e.code) {
      case 'invalid-email':
        return 'Bitte gib eine gültige E‑Mail-Adresse ein.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E‑Mail oder Passwort ist falsch.';
      case 'user-disabled':
        return 'Dieser Account ist deaktiviert.';
      case 'email-already-in-use':
        return 'Diese E‑Mail ist bereits registriert.';
      case 'weak-password':
        return 'Passwort ist zu schwach (mindestens 8 Zeichen).';
      case 'operation-not-allowed':
        return 'Anmeldung ist aktuell nicht erlaubt. Bitte prüfe die Firebase Auth Einstellungen.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte warte kurz und versuche es erneut.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Verbindung.';
      default:
        return msg.isNotEmpty ? msg : 'Anmeldung fehlgeschlagen.';
    }
  }

  Future<UserAccount> _ensureLocalUserFile({
    required String uid,
    required String email,
    UserProfile? profileOverride,
  }) async {
    final existing = await _storage.readJson(CustomerPaths.userFile(uid));
    if (existing != null) {
      final u = UserAccount.fromJson(existing);
      // If email changed in Firebase, keep local in sync.
      if (email.isNotEmpty && u.email != email) {
        final updated = u.copyWith(email: email);
        await _storage.writeJson(CustomerPaths.userFile(uid), updated.toJson());
        return updated;
      }
      return u;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final user = UserAccount(
      uid: uid,
      email: email,
      passwordHash: null,
      createdAt: nowIso,
      profile: profileOverride ?? const UserProfile(),
      flags: const UserFlags(isPremium: false, welcomeSeen: false),
    );
    await _storage.writeJson(CustomerPaths.userFile(uid), user.toJson());
    return user;
  }

  Future<String> register({
    required String email,
    required String password,
    required String confirmPassword,
    String? displayName,
    String? diet,
    List<String>? goals,
    List<String>? allergies,
    required bool acceptPrivacyAndTerms,
  }) async {
    // Web without Firebase config: local-only auth (for Chrome testing).
    if (_useWebLocalAuth) {
      final e = email.trim();
      if (!_emailRegex.hasMatch(e)) throw StateError('Bitte gib eine gültige E-Mail-Adresse ein.');
      if (password.length < 8) throw StateError('Passwort muss mindestens 8 Zeichen haben.');
      if (password != confirmPassword) throw StateError('Passwörter stimmen nicht überein.');
      if (!acceptPrivacyAndTerms) throw StateError('Bitte Datenschutz & AGB akzeptieren, um dich zu registrieren.');

      // Build local profile from overrides (no onboarding dependency here).
      final dn = (displayName ?? '').trim();
      final d = (diet ?? '').trim();
      final profile = UserProfile(
        displayName: dn,
        diet: d.isNotEmpty ? d : 'none',
        goals: goals ?? const [],
        allergies: allergies ?? const [],
        favoriteMarkets: const [],
      );

      final uid = _localUidForEmail(e);
      final prefs = await SharedPreferences.getInstance();
      final existingHash = prefs.getString(_pwHashKey(uid));
      if (existingHash != null && existingHash.isNotEmpty) {
        throw StateError('Diese E‑Mail ist bereits registriert.');
      }

      final salt = _randomSalt();
      await prefs.setString(_pwSaltKey(uid), salt);
      await prefs.setString(_pwHashKey(uid), _hashPassword(salt, password));

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await _ensureLocalUserFile(uid: uid, email: e, profileOverride: profile);
      await _writeSession(uid: uid, email: e);
      final sessionUser = await _ensureLocalUserFile(uid: uid, email: e, profileOverride: profile);
      _setWebLocalUser(sessionUser);

      final store = CustomerDataStore.instance;
      await store.saveProfile(
        CustomerProfile(
          userId: uid,
          email: e,
          name: profile.displayName.isNotEmpty ? profile.displayName : null,
          createdAt: nowIso,
          lastLoginAt: nowIso,
          consentAcceptedAt: nowIso,
        ),
      );
      await store.savePreferences(
        CustomerPreferences(
          diet: CustomerDietX.fromString(profile.diet.isNotEmpty ? profile.diet : 'none'),
          primaryGoal: (profile.goals).isNotEmpty ? profile.goals.first : null,
          dislikedIngredients: const [],
          allergens: (profile.allergies),
          calorieGoal: null,
          language: 'de',
          personalizationEnabled: true,
        ),
      );
      await store.saveAppStats(CustomerAppStats.defaults());
      await store.logEvent('register_local_web', {'uid': uid, 'email': e});
      await store.logEvent('login_local_web', {'uid': uid});
      if (kDebugMode) debugPrint('✅ Auth register(web-local): $e -> $uid');
      return uid;
    }

    if (!FirebaseBootstrap.firebaseAvailable) {
      throw StateError('Firebase ist nicht verfügbar. Bitte Firebase Setup prüfen und App neu starten.');
    }
    final e = email.trim();
    if (!_emailRegex.hasMatch(e)) {
      throw StateError('Bitte gib eine gültige E-Mail-Adresse ein.');
    }
    if (password.length < 8) {
      throw StateError('Passwort muss mindestens 8 Zeichen haben.');
    }
    if (password != confirmPassword) {
      throw StateError('Passwörter stimmen nicht überein.');
    }
    if (!acceptPrivacyAndTerms) {
      throw StateError('Bitte Datenschutz & AGB akzeptieren, um dich zu registrieren.');
    }

    // Optional migration from onboarding profile -> user profile
    UserProfile profile = const UserProfile();
    final onboarding = await OnboardingRepository.loadUserProfile();
    if (onboarding != null) {
      final dp = onboarding.dietPreferences;
      String diet = 'none';
      if (dp.contains(DietPreference.vegan)) {
        diet = 'vegan';
      } else if (dp.contains(DietPreference.vegetarian)) {
        diet = 'vegetarian';
      }

      final goals = <String>[];
      if (dp.contains(DietPreference.highProtein)) {
        goals.add('high_protein');
      }
      if (dp.contains(DietPreference.lowCarb)) {
        goals.add('low_carb');
      }

      final allergies = <String>[];
      final a = (onboarding.allergies ?? '').trim();
      if (a.isNotEmpty) {
        allergies.addAll(
          a.split(RegExp(r'[,;]'))
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty),
        );
      }

      final fav = <String>[];
      fav.addAll(onboarding.favoriteSupermarkets.map((s) => s.trim()).where((s) => s.isNotEmpty));
      final preferred = (onboarding.preferredSupermarket ?? '').trim();
      if (preferred.isNotEmpty && !fav.contains(preferred)) fav.add(preferred);

      profile = profile.copyWith(
        displayName: onboarding.name ?? '',
        diet: diet,
        goals: goals,
        allergies: allergies,
        favoriteMarkets: fav,
      );
    }

    // Explicit register form overrides (MVP)
    final dn = (displayName ?? '').trim();
    final d = (diet ?? '').trim();
    profile = profile.copyWith(
      displayName: dn.isNotEmpty ? dn : null,
      diet: d.isNotEmpty ? d : null,
      goals: goals,
      allergies: allergies,
    );

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: e, password: password);
      final fbUser = cred.user;
      if (fbUser == null) {
        throw StateError('Registrierung fehlgeschlagen (kein User zurückgegeben).');
      }

      // Keep displayName (optional) in Firebase user profile too (no Firestore involved).
      final dn = (profile.displayName).trim();
      if (dn.isNotEmpty) {
        await fbUser.updateDisplayName(dn);
      }

      // Send verification immediately (required by spec).
      try {
        await fbUser.sendEmailVerification();
        if (kDebugMode) debugPrint('✉️ Verification email sent: ${fbUser.email}');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Verification email send failed: $e');
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await _ensureLocalUserFile(uid: fbUser.uid, email: fbUser.email ?? e, profileOverride: profile);
      await _writeSession(uid: fbUser.uid, email: fbUser.email ?? e);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('consent_accepted_at', nowIso);

      if (kDebugMode) debugPrint('✅ Auth register(Firebase): $e -> ${fbUser.uid}');
      // No Firestore writes (auth-only setup).

    // Persist customer files (exportable)
    final store = CustomerDataStore.instance;
    await store.saveProfile(
      CustomerProfile(
        userId: fbUser.uid,
        email: e,
        name: profile.displayName.isNotEmpty ? profile.displayName : null,
        createdAt: nowIso,
        lastLoginAt: nowIso,
        consentAcceptedAt: nowIso,
      ),
    );
    await store.savePreferences(
      CustomerPreferences(
        diet: CustomerDietX.fromString(profile.diet.isNotEmpty ? profile.diet : 'none'),
        primaryGoal: (profile.goals).isNotEmpty ? profile.goals.first : null,
        dislikedIngredients: const [],
        allergens: (profile.allergies),
        calorieGoal: null,
        language: 'de',
        personalizationEnabled: true,
      ),
    );
    await store.saveAppStats(CustomerAppStats.defaults());
      await store.logEvent('register', {'uid': fbUser.uid, 'email': e});
      await store.logEvent('login', {'uid': fbUser.uid});
      return fbUser.uid;
    } on FirebaseAuthException catch (err) {
      throw StateError(_mapAuthError(err));
    }
  }

  Future<UserAccount> login({
    required String email,
    required String password,
  }) async {
    // Web without Firebase config: local-only auth (for Chrome testing).
    if (_useWebLocalAuth) {
      final e = email.trim();
      if (!_emailRegex.hasMatch(e)) throw StateError('Bitte gib eine gültige E-Mail-Adresse ein.');
      if (password.length < 8) throw StateError('Ungültiges Passwort.');

      final uid = _localUidForEmail(e);
      final prefs = await SharedPreferences.getInstance();
      final salt = prefs.getString(_pwSaltKey(uid));
      final hash = prefs.getString(_pwHashKey(uid));
      if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) {
        throw StateError('Kein Account gefunden. Bitte registriere dich zuerst.');
      }
      final attempt = _hashPassword(salt, password);
      if (attempt != hash) {
        throw StateError('E‑Mail oder Passwort ist falsch.');
      }

      final user = await _ensureLocalUserFile(uid: uid, email: e);
      await _writeSession(uid: uid, email: e);
      _setWebLocalUser(user);

      // Update customer profile lastLoginAt (exportable)
      final store = CustomerDataStore.instance;
      final existingProfile = await store.loadProfile();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (existingProfile != null && existingProfile.userId == user.uid) {
        await store.saveProfile(
          CustomerProfile(
            userId: existingProfile.userId,
            email: existingProfile.email,
            name: existingProfile.name,
            createdAt: existingProfile.createdAt,
            lastLoginAt: nowIso,
            consentAcceptedAt: existingProfile.consentAcceptedAt,
          ),
        );
      } else {
        await store.saveProfile(
          CustomerProfile(
            userId: user.uid,
            email: user.email,
            name: user.profile.displayName.isNotEmpty ? user.profile.displayName : null,
            createdAt: user.createdAt,
            lastLoginAt: nowIso,
            consentAcceptedAt: nowIso,
          ),
        );
      }
      await store.logEvent('login_local_web', {'uid': user.uid});
      if (kDebugMode) debugPrint('✅ Auth login(web-local): ${user.email} -> ${user.uid}');
      return user;
    }

    if (!FirebaseBootstrap.firebaseAvailable) {
      throw StateError('Firebase ist nicht verfügbar. Bitte Firebase Setup prüfen und App neu starten.');
    }
    final e = email.trim();
    if (!_emailRegex.hasMatch(e)) {
      throw StateError('Bitte gib eine gültige E-Mail-Adresse ein.');
    }
    if (password.length < 8) {
      throw StateError('Ungültiges Passwort.');
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: password);
      final fbUser = cred.user;
      if (fbUser == null) {
        throw StateError('Login fehlgeschlagen (kein User zurückgegeben).');
      }

      final user = await _ensureLocalUserFile(uid: fbUser.uid, email: fbUser.email ?? e);
      await _writeSession(uid: fbUser.uid, email: fbUser.email ?? e);
      if (kDebugMode) debugPrint('✅ Auth login(Firebase): ${fbUser.email} -> ${fbUser.uid}');
      // No Firestore writes (auth-only setup).

    // Update customer profile lastLoginAt (exportable)
    final store = CustomerDataStore.instance;
    final existingProfile = await store.loadProfile();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (existingProfile != null && existingProfile.userId == user.uid) {
      await store.saveProfile(
        CustomerProfile(
          userId: existingProfile.userId,
          email: existingProfile.email,
          name: existingProfile.name,
          createdAt: existingProfile.createdAt,
          lastLoginAt: nowIso,
          consentAcceptedAt: existingProfile.consentAcceptedAt,
        ),
      );
    } else {
      await store.saveProfile(
        CustomerProfile(
          userId: user.uid,
          email: user.email,
          name: user.profile.displayName.isNotEmpty ? user.profile.displayName : null,
          createdAt: user.createdAt,
          lastLoginAt: nowIso,
          consentAcceptedAt: nowIso,
        ),
      );
    }
      await store.logEvent('login', {'uid': user.uid});
      return user;
    } on FirebaseAuthException catch (err) {
      throw StateError(_mapAuthError(err));
    }
  }

  Future<UserAccount?> getCurrentUser() async {
    if (!FirebaseBootstrap.firebaseAvailable) {
      // Web local auth: use stored session keys
      if (_useWebLocalAuth) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final loggedIn = prefs.getBool('session_is_logged_in') ?? false;
          final uid = (prefs.getString('session_user_id') ?? '').trim();
          final email = (prefs.getString('session_email') ?? '').trim();
          if (!loggedIn || uid.isEmpty) return null;
          // Ensure local file exists (may be missing in older runs)
          final user = await _ensureLocalUserFile(uid: uid, email: email);
          _setWebLocalUser(user);
          return user;
        } catch (_) {
          return null;
        }
      }
      if (kDebugMode && !_loggedAuthUnavailable) {
        _loggedAuthUnavailable = true;
        debugPrint('ℹ️ Auth: firebase unavailable -> no session');
      }
      return null;
    }
    final fbUser = getCurrentUserSafe();
    if (fbUser == null) return null;
    try {
      final email = (fbUser.email ?? '').trim();
      // Keep old session keys in sync for existing UI.
      await _writeSession(uid: fbUser.uid, email: email);
      return _ensureLocalUserFile(uid: fbUser.uid, email: email);
    } catch (e) {
      if (kDebugMode && !_loggedAuthUnavailable) {
        _loggedAuthUnavailable = true;
        debugPrint('⚠️ Auth getCurrentUser failed (safe ignored): $e');
      }
      return null;
    }
  }

  Future<void> markWelcomeSeen(String uid) async {
    final json = await _storage.readJson(CustomerPaths.userFile(uid));
    if (json == null) return;
    final user = UserAccount.fromJson(json);
    if (user.flags.welcomeSeen) return;
    final updated = user.copyWith(
      flags: UserFlags(isPremium: user.flags.isPremium, welcomeSeen: true),
    );
    await _storage.writeJson(CustomerPaths.userFile(uid), updated.toJson());
  }

  Future<void> requestPasswordResetStub(String email) async {
    if (!FirebaseBootstrap.firebaseAvailable) {
      if (_useWebLocalAuth) {
        throw StateError('Passwort-Reset ist im Web-Local-Modus nicht verfügbar. Bitte registriere dich neu.');
      }
      throw StateError('Firebase ist nicht verfügbar. Bitte Firebase Setup prüfen und App neu starten.');
    }
    final e = email.trim();
    if (!_emailRegex.hasMatch(e)) {
      throw StateError('Bitte gib eine gültige E-Mail-Adresse ein.');
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: e);
    } on FirebaseAuthException catch (err) {
      throw StateError(_mapAuthError(err));
    }
    await CustomerDataStore.instance.logEvent('password_reset_requested', {'email': e});
  }
}


