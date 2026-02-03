import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/firebase/firebase_guard.dart';
import '../../../core/storage/customer_storage.dart';

typedef FirestoreUserSnapshot = ({
  String uid,
  String email,
  String previousLastOpenDate,
  String lastOpenDate,
  int streakCount,
  int appOpenCount,
  Map<String, bool> preferences,
  bool didCountToday,
  String storage, // firestore | local_fallback
});

class FirestoreUserService {
  FirestoreUserService._();
  static final FirestoreUserService instance = FirestoreUserService._();

  final _storage = CustomerStorage.instance;

  FirebaseFirestore? get _db => FirebaseBootstrap.firebaseAvailable
      ? FirebaseGuard.safeFirebase(() => FirebaseFirestore.instance)
      : null;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db!.collection('users').doc(uid);

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

  Map<String, bool> _normalizePrefs(dynamic prefs) {
    if (prefs is Map) {
      final m = prefs.cast<String, dynamic>();
      return {
        'vegetarian': m['vegetarian'] == true,
        'vegan': m['vegan'] == true,
      };
    }
    return const {'vegetarian': false, 'vegan': false};
  }

  dynamic _toJsonSafe(dynamic v) {
    if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
    if (v is DateTime) return v.toUtc().toIso8601String();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _toJsonSafe(val)));
    }
    if (v is List) {
      return v.map(_toJsonSafe).toList();
    }
    return v;
  }

  Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, _toJsonSafe(v)));
  }

  Future<void> _exportLocal({
    required String uid,
    required Map<String, dynamic> data,
    required String storageLabel,
  }) async {
    final exportData = _jsonSafeMap(data);
    final export = <String, dynamic>{
      ...exportData,
      '_exportedAt': DateTime.now().toUtc().toIso8601String(),
      '_storage': storageLabel,
    };

    // Requirement: dates_from_costumors/<uid>.json (root file).
    try {
      await _storage.writeJson('$uid.json', export);
      if (kDebugMode) {
        debugPrint('💾 Export OK: dates_from_costumors/$uid.json (${_storage.rootDebugPath ?? "web virtual"})');
      }
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Export failed (CustomerStorage): $e');
    }

    // Fallback: SharedPreferences (no crash).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('export_user_$uid', json.encode(export));
      if (kDebugMode) debugPrint('💾 Export fallback OK: SharedPreferences key=export_user_$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Export fallback failed (SharedPreferences): $e');
    }
  }

  /// Ensures `users/<uid>` exists and contains the required base fields.
  /// Does NOT touch `lastLoginAt`.
  Future<void> ensureUserDoc({required String uid, required String email}) async {
    if (!FirebaseBootstrap.firebaseAvailable || _db == null) return;
    try {
      await _db!.runTransaction((tx) async {
        final ref = _doc(uid);
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final hasCreatedAt = data.containsKey('createdAt') && data['createdAt'] != null;

        tx.set(
          ref,
          {
            'email': email,
            if (!hasCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'preferences': _normalizePrefs(data['preferences']),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Firestore ensureUserDoc failed: $e');
    }
  }

  /// Called on successful login/register.
  Future<void> onLogin({required String uid, required String email}) async {
    if (!FirebaseBootstrap.firebaseAvailable || _db == null) return;
    try {
      await ensureUserDoc(uid: uid, email: email);
      await _doc(uid).set(
        {
          'email': email,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Firestore onLogin failed: $e');
    }
  }

  /// Streak logic (DSGVO-friendly): only `users/<uid>` is touched.
  ///
  /// Rules:
  /// - If lastOpenDate == today: do nothing (no increment)
  /// - Else: appOpenCount += 1
  ///   - If lastOpenDate == yesterday: streakCount += 1
  ///   - Else: streakCount = 1
  /// - lastOpenDate set to today
  Future<FirestoreUserSnapshot> onAppOpen({required String uid, required String email}) async {
    final now = DateTime.now();
    final today = _todayKey(now);

    if (!FirebaseBootstrap.firebaseAvailable || _db == null) {
      return _fallbackOnAppOpen(uid: uid, email: email, today: today);
    }

    try {
      await ensureUserDoc(uid: uid, email: email); // ensures base doc exists

      String previous = '';
      bool alreadyCounted = false;

      await _db!.runTransaction((tx) async {
        final ref = _doc(uid);
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};

        final prev = (data['lastOpenDate']?.toString() ?? '').trim();
        previous = prev;
        final prevStreak = (data['streakCount'] as num?)?.toInt() ?? 0;
        final prevOpens = (data['appOpenCount'] as num?)?.toInt() ?? 0;
        final prefs = _normalizePrefs(data['preferences']);

        // today already counted -> no changes
        if (prev == today) {
          alreadyCounted = true;
          tx.set(
            ref,
            {
              'email': email,
              'updatedAt': FieldValue.serverTimestamp(),
              'preferences': prefs,
            },
            SetOptions(merge: true),
          );
          return;
        }

        int nextStreak;
        if (prev.isEmpty) {
          nextStreak = 1;
        } else {
          final last = _parseDay(prev);
          final td = _parseDay(today);
          final diff = td.difference(last).inDays;
          if (diff == 1) {
            nextStreak = (prevStreak <= 0) ? 1 : (prevStreak + 1);
          } else {
            nextStreak = 1;
          }
        }

        tx.set(
          ref,
          {
            'email': email,
            'lastOpenDate': today,
            'streakCount': nextStreak,
            'appOpenCount': prevOpens + 1,
            'preferences': prefs,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      final after = await _doc(uid).get();
      final data = after.data() ?? <String, dynamic>{};

      final lastOpenDate = (data['lastOpenDate']?.toString() ?? '').trim();
      final streakCount = (data['streakCount'] as num?)?.toInt() ?? 0;
      final appOpenCount = (data['appOpenCount'] as num?)?.toInt() ?? 0;
      final prefs = _normalizePrefs(data['preferences']);

      await _exportLocal(uid: uid, data: data, storageLabel: 'firestore');

      debugPrint(
        '📊 FirestoreUser: uid=$uid appOpenCount=$appOpenCount streakCount=$streakCount '
        'lastOpenDate=$lastOpenDate prefs=$prefs storage=firestore',
      );

      return (
        uid: uid,
        email: email,
        previousLastOpenDate: previous,
        lastOpenDate: lastOpenDate,
        streakCount: streakCount,
        appOpenCount: appOpenCount,
        preferences: prefs,
        didCountToday: !alreadyCounted,
        storage: 'firestore',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Firestore onAppOpen failed -> fallback: $e');
      return _fallbackOnAppOpen(uid: uid, email: email, today: today);
    }
  }

  Future<FirestoreUserSnapshot> _fallbackOnAppOpen({
    required String uid,
    required String email,
    required String today,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prev = (prefs.getString('fb_user_lastOpenDate_$uid') ?? '').trim();
      final prevStreak = prefs.getInt('fb_user_streakCount_$uid') ?? 0;
      final prevOpens = prefs.getInt('fb_user_appOpenCount_$uid') ?? 0;
      final vegetarian = prefs.getBool('fb_user_pref_vegetarian_$uid') ?? false;
      final vegan = prefs.getBool('fb_user_pref_vegan_$uid') ?? false;
      final prefMap = {'vegetarian': vegetarian, 'vegan': vegan};

      // today already counted -> no changes
      if (prev == today) {
        if (kDebugMode) {
          debugPrint(
            '📊 FirestoreUser(fallback): uid=$uid appOpenCount=$prevOpens streakCount=$prevStreak '
            'lastOpenDate=$prev prefs=$prefMap storage=local_fallback (today already counted)',
          );
        }
        await _exportLocal(
          uid: uid,
          data: {
            'email': email,
            'lastOpenDate': prev,
            'streakCount': prevStreak,
            'appOpenCount': prevOpens,
            'preferences': prefMap,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          storageLabel: 'local_fallback',
        );
        return (
          uid: uid,
          email: email,
          previousLastOpenDate: prev,
          lastOpenDate: prev,
          streakCount: prevStreak,
          appOpenCount: prevOpens,
          preferences: prefMap,
          didCountToday: false,
          storage: 'local_fallback',
        );
      }

      int nextStreak;
      if (prev.isEmpty) {
        nextStreak = 1;
      } else {
        final last = _parseDay(prev);
        final td = _parseDay(today);
        final diff = td.difference(last).inDays;
        if (diff == 1) {
          nextStreak = (prevStreak <= 0) ? 1 : (prevStreak + 1);
        } else {
          nextStreak = 1;
        }
      }

      final nextOpens = prevOpens + 1;
      await prefs.setString('fb_user_lastOpenDate_$uid', today);
      await prefs.setInt('fb_user_streakCount_$uid', nextStreak);
      await prefs.setInt('fb_user_appOpenCount_$uid', nextOpens);
      await prefs.setBool('fb_user_pref_vegetarian_$uid', vegetarian);
      await prefs.setBool('fb_user_pref_vegan_$uid', vegan);

      final local = <String, dynamic>{
        'email': email,
        'createdAt': null,
        'lastLoginAt': null,
        'lastOpenDate': today,
        'streakCount': nextStreak,
        'appOpenCount': nextOpens,
        'preferences': prefMap,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      await _exportLocal(uid: uid, data: local, storageLabel: 'local_fallback');

      if (kDebugMode) {
        debugPrint(
          '📊 FirestoreUser(fallback): uid=$uid appOpenCount=$nextOpens streakCount=$nextStreak '
          'lastOpenDate=$today prefs=$prefMap storage=local_fallback',
        );
      }

      return (
        uid: uid,
        email: email,
        previousLastOpenDate: prev,
        lastOpenDate: today,
        streakCount: nextStreak,
        appOpenCount: nextOpens,
        preferences: prefMap,
        didCountToday: true,
        storage: 'local_fallback',
      );
    } catch (e) {
      // Absolute last resort: return safe defaults, no crash.
      if (kDebugMode) debugPrint('⚠️ FirestoreUser(fallback) failed hard: $e');
      return (
        uid: uid,
        email: email,
        previousLastOpenDate: '',
        lastOpenDate: today,
        streakCount: 1,
        appOpenCount: 1,
        preferences: const {'vegetarian': false, 'vegan': false},
        didCountToday: true,
        storage: 'local_fallback',
      );
    }
  }
}


