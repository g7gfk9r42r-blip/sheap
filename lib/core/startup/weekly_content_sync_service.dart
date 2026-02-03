import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/recipe.dart';
import '../../data/repositories/cached_recipe_repository.dart';
import 'app_globals.dart';

class WeeklyContentSyncService {
  WeeklyContentSyncService._();
  static final WeeklyContentSyncService instance = WeeklyContentSyncService._();

  static const _prefsMetaWeekKey = 'remote_meta_week_key';
  static const _prefsMetaUpdatedAt = 'remote_meta_updated_at';
  static const _prefsLastCheckedAtMs = 'remote_meta_checked_at_ms';

  // Don’t spam the server every hot restart / app open.
  static const Duration _minCheckInterval = Duration(minutes: 15);

  // Keep image warmup small to avoid heavy bandwidth.
  static const int _prefetchImageCount = 24;

  String _baseUrl() {
    const s = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return s.trim().replaceAll(RegExp(r'/$'), '');
  }

  Future<void> runOncePerLaunch() async {
    final base = _baseUrl();
    if (base.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckedMs = prefs.getInt(_prefsLastCheckedAtMs) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (lastCheckedMs > 0 && (nowMs - lastCheckedMs) < _minCheckInterval.inMilliseconds) {
        return;
      }
      await prefs.setInt(_prefsLastCheckedAtMs, nowMs);

      final meta = await _fetchMeta(base);
      if (meta == null) return;

      final prevWeek = (prefs.getString(_prefsMetaWeekKey) ?? '').trim();
      final prevUpdated = (prefs.getString(_prefsMetaUpdatedAt) ?? '').trim();
      final changed = meta.weekKey.isNotEmpty &&
          (meta.weekKey != prevWeek || (meta.updatedAt.isNotEmpty && meta.updatedAt != prevUpdated));

      if (!changed) {
        // Still warm images lightly from cached data (cheap).
        final recipes = await CachedRecipeRepository.instance.loadAllCached();
        await _prefetchSomeImages(base, recipes);
        return;
      }

      if (kDebugMode) {
        debugPrint('🔄 Weekly sync: new content detected week=${meta.weekKey} updated_at=${meta.updatedAt}');
      }

      await prefs.setString(_prefsMetaWeekKey, meta.weekKey);
      if (meta.updatedAt.isNotEmpty) await prefs.setString(_prefsMetaUpdatedAt, meta.updatedAt);

      // Force-refresh remote recipes cache, then warm images.
      final recipes = await CachedRecipeRepository.instance.refreshRemote(weekKeyOverride: meta.weekKey);
      await _prefetchSomeImages(base, recipes);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ WeeklyContentSyncService failed (ignored): $e');
    }
  }

  Future<_RemoteMeta?> _fetchMeta(String base) async {
    try {
      // Prefer /meta (dynamic), fallback to /media/meta.json (alias).
      final urls = <String>[
        '$base/meta',
        '$base/media/meta.json',
      ];
      for (final u in urls) {
        try {
          final resp = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 3));
          if (resp.statusCode != 200) continue;
          final decoded = json.decode(resp.body);
          if (decoded is Map<String, dynamic>) {
            final wk = (decoded['week_key'] ?? decoded['weekKey'] ?? '').toString().trim();
            final ua = (decoded['updated_at'] ?? decoded['updatedAt'] ?? '').toString().trim();
            return _RemoteMeta(weekKey: wk, updatedAt: ua);
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _prefetchSomeImages(String base, List<Recipe> recipes) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    final candidates = <String>[];
    for (final r in recipes) {
      final hero = (r.heroImageUrl ?? '').trim();
      if (hero.isEmpty) continue;

      if (hero.startsWith('http://') || hero.startsWith('https://')) {
        candidates.add(hero);
        continue;
      }
      if (hero.startsWith('assets/recipe_images/')) {
        final rel = hero.replaceFirst('assets/', '');
        candidates.add('$base/media/$rel');
        continue;
      }
      // If hero is stored as "media/recipe_images/..." or "recipe_images/..."
      if (hero.contains('recipe_images/')) {
        final idx = hero.indexOf('recipe_images/');
        final rel = hero.substring(idx);
        candidates.add('$base/media/$rel');
        continue;
      }
    }

    if (candidates.isEmpty) return;

    // Prefetch only a small amount.
    final take = candidates.take(_prefetchImageCount).toList();
    for (final url in take) {
      try {
        await precacheImage(NetworkImage(url), ctx);
      } catch (_) {
        // ignore
      }
    }
  }
}

class _RemoteMeta {
  final String weekKey;
  final String updatedAt;
  _RemoteMeta({required this.weekKey, required this.updatedAt});
}


