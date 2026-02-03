import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import '../../features/customer/data/customer_data_store.dart';
import '../../data/repositories/cached_recipe_repository.dart';
import '../storage/customer_storage.dart';
import '../../features/auth/data/auth_service_local.dart';
import '../firebase/firebase_bootstrap.dart';
import '../../features/recipes/data/recipe_loader_from_prospekte.dart';
import '../../features/recipes/utils/recipe_image_path_resolver.dart';
import '../../features/recipes/domain/recipe_personalization_service.dart';
import 'data_health_check_service.dart';
import 'startup_diagnostics.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class AppStartupDiagnostics {
  AppStartupDiagnostics._();
  static final AppStartupDiagnostics instance = AppStartupDiagnostics._();
  static bool _printed = false;

  Future<void> runOnce() async {
    if (!kDebugMode) return;
    if (_printed) return;
    _printed = true;

    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('=== STARTUP DIAGNOSTICS ===');
    debugPrint('════════════════════════════════════════════════════════════');
    // 1) Firebase
    debugPrint('🧩 Firebase: available=${FirebaseBootstrap.firebaseAvailable} initError=${FirebaseBootstrap.lastFirebaseInitError ?? "none"}');
    debugPrint(
      '🧩 FirebaseOptions: file=${FirebaseBootstrap.optionsFilePresent ? "present" : "missing"} '
      'usable=${FirebaseBootstrap.optionsUsable}${FirebaseBootstrap.optionsError != null ? " (error=${FirebaseBootstrap.optionsError})" : ""}',
    );

    // 2) Auth
    final authUser = AuthServiceLocal.instance.getCurrentUserSafe();
    final authReason = FirebaseBootstrap.firebaseAvailable
        ? (authUser == null ? 'signed_out' : 'signed_in')
        : 'firebase_unavailable';
    debugPrint('🧩 Auth: session=${authUser?.email ?? "null"} reason=$authReason');

    // Actionable fixes (single section, no spam)
    if (!FirebaseBootstrap.firebaseAvailable) {
      debugPrint('🛠️ Fixes:');
      if (!FirebaseBootstrap.optionsUsable) {
        debugPrint('   - Fix: Run `flutterfire configure` OR replace `lib/firebase_options.dart` with the generated one.');
      }
      debugPrint('   - Fix: Verify `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` exist and match your app IDs.');
      debugPrint('   - Fix (iOS Pods): Ensure iOS uses Flutter/Debug.xcconfig + Release.xcconfig which include Pods-Runner.*.xcconfig.');
    }

    await _checkAssetManifest();
    await _checkAsset('Logo', 'assets/Logo Jawoll/logo.png');
    await _checkAsset('Legal Datenschutz', 'assets/legal/datenschutz.md');
    await _checkAsset('Legal AGB', 'assets/legal/agb.md');
    await _checkAsset('Legal Impressum', 'assets/legal/impressum.md');

    await _checkStorageWritable();
    await _checkPrefs();
    await _checkDataHealth();
    await _checkRecipesAndImages();
    await _checkPopupState();
    await _checkIap();

    debugPrint('════════════════════════════════════════════════════════════');
  }

  Future<void> _checkAssetManifest() async {
    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final decoded = json.decode(raw);
      final count = (decoded is Map) ? decoded.length : (decoded is List ? decoded.length : 0);
      debugPrint('✅ Assets Manifest loaded: $count');
    } catch (e) {
      debugPrint('❌ Assets Manifest missing/unreadable');
      debugPrint('   Fix: ensure flutter assets are configured correctly in pubspec.yaml');
      debugPrint('   Error: $e');
    }
  }

  Future<void> _checkAsset(String label, String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      debugPrint('✅ Assets: $label found ($assetPath)');
    } catch (e) {
      debugPrint('❌ Assets: $label missing ($assetPath)');
      debugPrint('   Next step: add to pubspec.yaml assets include -> "$assetPath"');
      debugPrint('   Error: $e');
    }
  }

  Future<void> _checkStorageWritable() async {
    try {
      await CustomerStorage.instance.writeText('diagnostics_write_test.txt', 'ok');
      await CustomerStorage.instance.delete('diagnostics_write_test.txt');
      debugPrint('✅ Auth Storage: dates_from_costumors write OK (${CustomerStorage.instance.rootDebugPath ?? "web virtual"})');
    } catch (e) {
      debugPrint('❌ Auth Storage: cannot write dates_from_costumors');
      debugPrint('   Next step: check path_provider integration / permissions');
      debugPrint('   Error: $e');
    }
  }

  Future<void> _checkPrefs() async {
    try {
      final profile = await CustomerDataStore.instance.loadProfile();
      final prefs = await CustomerDataStore.instance.loadPreferences();
      final stats = await CustomerDataStore.instance.loadAppStats();
      debugPrint('✅ Customer files: profile=${profile != null ? "loaded" : "missing"} prefsDiet=${prefs.diet} stats(streak=${stats.streakDays}, lastOpen=${stats.lastOpenDate})');
    } catch (e) {
      debugPrint('⚠️ Customer files: load failed');
      debugPrint('   Error: $e');
    }
  }

  Future<void> _checkDataHealth() async {
    final r = await DataHealthCheckService.instance.run();
    DataHealthCheckService.instance.printResult(r);
  }

  Future<void> _checkPopupState() async {
    try {
      final user = await AuthServiceLocal.instance.getCurrentUser();
      if (user == null) {
        debugPrint('✅ Popup: no session -> popup disabled');
        return;
      }
      try {
        final stats = await CustomerDataStore.instance.loadAppStats();
        debugPrint('✅ Popup: session uid=${user.uid} lastOpenDate=${stats.lastOpenDate} (popup decision logged by StreakService)');
      } catch (e) {
        debugPrint('⚠️ Popup: could not load stats for decision');
        debugPrint('   Error: $e');
      }
    } catch (e) {
      // Safe-guard: on simulators/dev builds Firebase might be missing -> do not crash diagnostics.
      debugPrint('ℹ️ Popup: skipped (auth unavailable)');
      debugPrint('   Error: $e');
    }
  }

  Future<void> _checkRecipesAndImages() async {
    try {
      final recipeFiles = await RecipeLoaderFromProspekte.discoverRecipeFiles();
      debugPrint('✅ Recipe JSON files found: ${recipeFiles.length} (markets: ${recipeFiles.keys.join(", ")})');

      // Wrong filenames under assets/prospekte (e.g. aldi_nord.json)
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestRaw);
      final paths = <String>[];
      if (manifest is Map) {
        paths.addAll(manifest.keys.map((e) => e.toString()));
      } else if (manifest is List) {
        paths.addAll(manifest.map((e) => e.toString()));
      }
      final wrong = paths
          .where((p) => p.startsWith('assets/prospekte/') && p.endsWith('.json') && !p.endsWith('_recipes.json'))
          .toList();
      if (wrong.isNotEmpty) {
        debugPrint('❌ WRONG FILENAMES (expected *_recipes.json):');
        for (final w in wrong.take(10)) {
          debugPrint('   - $w');
        }
        debugPrint('   Fix: rename to assets/prospekte/<market>/<market>_recipes.json');
      } else {
        debugPrint('✅ Recipe filenames: ok (*_recipes.json)');
      }

      // Images count per market (assets/images/<market>_R###.*)
      final imagePaths = paths.where((p) => p.startsWith('assets/images/') && p.contains('_R') && (p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.webp'))).toList();
      final counts = <String, int>{};
      for (final p in imagePaths) {
        final file = p.split('/').last;
        final idx = file.indexOf('_R');
        if (idx <= 0) continue;
        final market = file.substring(0, idx).toLowerCase().trim();
        counts[market] = (counts[market] ?? 0) + 1;
      }
      debugPrint('✅ Images found: ${imagePaths.length} (markets: ${counts.length})');

      // Load recipes once (cached) and run market diagnostics report (single source)
      final recipes = await CachedRecipeRepository.instance.loadAllCached();
      debugPrint('✅ Recipes loaded: ${recipes.length}');

      // Personalization hit-rate (uses locally exported preferences, no recipe reload)
      try {
        final user = await AuthServiceLocal.instance.getCurrentUser();
        if (user != null) {
          final pref = await RecipePersonalizationService.instance.loadPrefsForUid(user.uid);
          final personalized = RecipePersonalizationService.instance.personalize(
            recipes: recipes,
            prefs: pref.prefs,
            source: pref.source,
          );
          debugPrint(
            '✅ Personalization hits: ${personalized.personalizedHits}/${recipes.length} '
            'prefs=${personalized.prefs} source=${pref.source}',
          );
        } else {
          debugPrint('ℹ️ Personalization hits: skipped (no session)');
        }
      } catch (e) {
        debugPrint('ℹ️ Personalization hits: skipped (auth unavailable)');
        debugPrint('   Error: $e');
      }

      final marketDiagnostics = RecipeLoaderFromProspekte.getMarketDiagnostics() ?? {};
      final report = await StartupDiagnostics.instance.runDiagnostics(
        recipes: recipes,
        recipeFiles: recipeFiles,
        marketDiagnostics: marketDiagnostics,
      );
      report.printReport();

      // Matched recipe->images (using resolved heroImageUrl)
      final matched = recipes.where((r) => (r.heroImageUrl ?? '').startsWith('assets/images/')).length;
      debugPrint('✅ Matched recipe->images: $matched/${recipes.length}');

      // Warnings / inconsistencies summary
      final warningsCount = recipes.where((r) => (r.warnings ?? const <String>[]).isNotEmpty).length;
      debugPrint('⚠️ Recipes with warnings: $warningsCount/${recipes.length}');

      // Ensure resolver order (root first)
      final resolvedExample = recipes.isNotEmpty
          ? await RecipeImagePathResolver.resolveImagePath(market: recipes.first.market ?? recipes.first.retailer, recipeId: recipes.first.id)
          : null;
      debugPrint('✅ Image resolver mode: asset (example: ${resolvedExample ?? "-"})');
    } catch (e) {
      debugPrint('⚠️ Recipes/Images diagnostics: failed');
      debugPrint('   Error: $e');
    }
  }

  Future<void> _checkIap() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (available) {
        debugPrint('✅ IAP: storekit available');
      } else {
        debugPrint('⚠️ IAP: storekit_no_response (safe ignored)');
        debugPrint('   Fix: test on real device / TestFlight + configure App Store Connect product');
      }
    } catch (e) {
      debugPrint('⚠️ IAP: storekit_no_response (safe ignored)');
      debugPrint('   Error: $e');
    }
  }
}


