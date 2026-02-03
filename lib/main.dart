import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/grocify_theme.dart';
import 'core/storage/customer_storage.dart';
import 'core/firebase/firebase_guard.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/diagnostics/firebase_startup_diagnostics.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/premium/premium_service.dart';
import 'core/assets/asset_index_service.dart';
import 'features/debug/asset_audit.dart';
import 'core/diagnostics/app_startup_diagnostics.dart';
import 'data/repositories/cached_recipe_repository.dart';
import 'core/startup/app_globals.dart';
import 'core/startup/weekly_content_sync_service.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    // IMPORTANT: ensureInitialized must run in the SAME zone as runApp (prevents "Zone mismatch")
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('❌ FlutterError: ${details.exceptionAsString()}');
    };

    ErrorWidget.builder = (details) {
      return Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'APP ERROR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  Text(details.exceptionAsString(), style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
          ),
        ),
      );
    };

    // Optional: load .env if present (do not crash if missing)
    try {
      // On Web, dotenv.load triggers a fetch for assets/.env (404 in this repo by design).
      // Only load dotenv on Web if explicitly requested.
      const loadDotenvOnWeb = bool.fromEnvironment('LOAD_DOTENV_ON_WEB', defaultValue: false);
      if (!kIsWeb || loadDotenvOnWeb) {
        await dotenv.load(fileName: '.env');
      }
    } catch (_) {}

    // Boot step 1: customer storage is independent from Firebase
    await CustomerStorage.instance.init();
    if (kDebugMode) {
      debugPrint('📁 dates_from_costumors ready: ${CustomerStorage.instance.rootDebugPath ?? '(web virtual)'}');
    }

    // Boot step 2: Firebase init (must NOT crash app if missing/misconfigured)
    FirebaseBootstrap.optionsFilePresent = true; // compiled in repo
    await FirebaseBootstrap.initFirebase();

    // Web only: ensure auth persists across reloads in Chrome (when not in preview mode).
    const webPreviewNoAuth = bool.fromEnvironment('WEB_PREVIEW_NO_AUTH', defaultValue: false);
    if (kIsWeb && !webPreviewNoAuth && FirebaseBootstrap.firebaseAvailable) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        if (kDebugMode) debugPrint('🔐 Auth(web): persistence=LOCAL');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Auth(web): setPersistence failed: $e');
      }
    }

    // Keep FirebaseGuard in sync (legacy callers)
    FirebaseGuard.initAttempted = true;
    FirebaseGuard.initError = FirebaseBootstrap.lastFirebaseInitError;

    debugPrint('✅ Firebase available: ${FirebaseBootstrap.firebaseAvailable}');
    if (FirebaseBootstrap.firebaseAvailable) {
      final u = FirebaseGuard.safeFirebase(() => FirebaseAuth.instance.currentUser);
      debugPrint(
        '🔐 Auth(start): state=${u == null ? "signed_out" : "signed_in"} '
        'uid=${u?.uid ?? "-"} emailVerified=${u?.emailVerified ?? false} email=${u?.email ?? "-"}',
      );
    } else {
      debugPrint('ℹ️ Auth/Personalization/Popups disabled (firebase unavailable)');
    }

    // IMPORTANT: runApp as early as possible (everything below runs in background)
    runApp(const GrocifyApp());

    // Heavy/diagnostic startup work: run after first frame so UI appears instantly.
    unawaited(Future<void>(() async {
      // Firebase-specific diagnostics (debug only, single block, no spam)
      await FirebaseStartupDiagnostics.printOnce();

      // These are expensive on web (large asset scans). Keep them off by default on web.
      if (kDebugMode && !kIsWeb) {
        await AppStartupDiagnostics.instance.runOnce();
        AssetAudit.run().catchError((error) {
          debugPrint('Asset Audit error: $error');
        });
      }

      // Non-critical services: do not block first render.
      if (FirebaseBootstrap.firebaseAvailable) {
        await PremiumService.instance.initialize();
      } else {
        if (kDebugMode) debugPrint('ℹ️ Premium: skipped (firebase unavailable)');
      }

      // Load Asset Index (optional; app can fall back to AssetManifest.json)
      await AssetIndexService.instance.loadIndex();

      // Weekly remote sync + small image warmup (background, no UI changes).
      await WeeklyContentSyncService.instance.runOncePerLaunch();
    }));
  }, (error, stack) {
    debugPrint('❌ Uncaught zone error: $error\n$stack');
  });
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Avoid Navigator calls during build (can trigger navigator._debugLocked on web).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigated) return;
      _navigated = true;
      _checkOnboarding();
    });
  }

  Future<void> _checkOnboarding() async {
    // Preload a bit so the first screen doesn't feel empty.
    // Never block forever (store review hates endless spinners).
    try {
      await Future.wait([
        WeeklyContentSyncService.instance.runOncePerLaunch().timeout(const Duration(seconds: 2)),
        CachedRecipeRepository.instance.loadAllCached().timeout(const Duration(seconds: 3)),
        AssetIndexService.instance.loadIndex().timeout(const Duration(seconds: 3)),
      ]).timeout(const Duration(seconds: 3));
    } catch (_) {}

    // IMPORTANT: Login should be the first thing a fresh install sees (unless DISABLE_AUTH is enabled).
    // Post-login onboarding is handled inside AuthGate (not here).
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: GrocifyTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Text('🍽️', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lade Rezepte…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class GrocifyApp extends StatelessWidget {
  const GrocifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sheap',
      theme: GrocifyTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const _SplashScreen(),
        '/': (_) => const AuthGate(),
      },
    );
  }
}