import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/grocify_theme.dart';
import '../../../app/main_navigation.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../data/auth_service_local.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../onboarding/onboarding_repository.dart';
import 'auth_flow.dart';
import 'verify_email_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Store-test / release builds can bypass auth entirely.
    const disableAuth = bool.fromEnvironment('DISABLE_AUTH', defaultValue: false);
    // Safety: never allow auth bypass in real release builds by accident.
    // If you truly need a no-login release build, introduce a dedicated flavor instead.
    final effectiveDisableAuth = disableAuth && !kReleaseMode;
    if (disableAuth && kReleaseMode && kDebugMode) {
      debugPrint('⚠️ AuthGate: DISABLE_AUTH=true ignored in RELEASE (safety).');
    }
    if (effectiveDisableAuth) {
      if (kDebugMode) debugPrint('ℹ️ AuthGate: DISABLE_AUTH=true -> bypass auth');
      return const MainNavigation();
    }

    // Web/Chrome: support two modes
    // - Preview mode (no auth): set --dart-define=WEB_PREVIEW_NO_AUTH=true
    // - Auth mode: omit or set false (requires Firebase web config)
    const webPreviewNoAuth = bool.fromEnvironment('WEB_PREVIEW_NO_AUTH', defaultValue: false);
    final effectiveWebPreviewNoAuth = kIsWeb && webPreviewNoAuth && !kReleaseMode;
    if (webPreviewNoAuth && kReleaseMode && kDebugMode) {
      debugPrint('⚠️ AuthGate: WEB_PREVIEW_NO_AUTH=true ignored in RELEASE (safety).');
    }
    if (effectiveWebPreviewNoAuth) {
      if (kDebugMode) debugPrint('ℹ️ AuthGate(web): preview mode -> bypass auth');
      return const MainNavigation();
    }

    // Web without Firebase config: use local auth fallback (email/password stored locally).
    if (kIsWeb && !FirebaseBootstrap.firebaseAvailable) {
      return const _WebLocalAuthGate();
    }

    if (!FirebaseBootstrap.firebaseAvailable) {
      return _FirebaseInitError(error: FirebaseBootstrap.lastFirebaseInitError);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GateLoading();
        }

        final user = snapshot.data;
        if (kDebugMode) {
          debugPrint(
            '🔐 AuthGate: state=${user == null ? "signed_out" : "signed_in"} '
            'uid=${user?.uid ?? "-"} emailVerified=${user?.emailVerified ?? false}',
          );
        }

        if (user == null) return const AuthFlow();
        if (user.emailVerified != true) return const VerifyEmailScreen();
        return const _PostLoginOnboardingGate();
      },
    );
  }
}

class _WebLocalAuthGate extends StatelessWidget {
  const _WebLocalAuthGate();

  @override
  Widget build(BuildContext context) {
    // Ensure we load the persisted local session once.
    // (FutureBuilder would not update after login/register; ValueNotifier does.)
    AuthServiceLocal.instance.getCurrentUser();

    return ValueListenableBuilder(
      valueListenable: AuthServiceLocal.webLocalUser,
      builder: (context, user, _) {
        if (kDebugMode) {
          debugPrint('🔐 AuthGate(web-local): state=${user == null ? "signed_out" : "signed_in"} uid=${user?.uid ?? "-"}');
        }
        if (user == null) return const AuthFlow();
        return const _PostLoginOnboardingGate();
      },
    );
  }
}

class _PostLoginOnboardingGate extends StatelessWidget {
  const _PostLoginOnboardingGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingRepository.isOnboardingCompleted(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _GateLoading();
        }
        final done = snap.data ?? false;
        if (!done) return const OnboardingFlow();
        return const MainNavigation();
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: GrocifyTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Text('🍽️', style: TextStyle(fontSize: 44)),
            ),
            const SizedBox(height: 22),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _FirebaseInitError extends StatelessWidget {
  final Object? error;
  const _FirebaseInitError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: GrocifyTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GrocifyTheme.border.withOpacity(0.65)),
                  boxShadow: GrocifyTheme.shadowMD,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firebase init failed',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GrocifyTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Firebase konnte nicht initialisiert werden. '
                      'Die App startet trotzdem, aber Login/Registrierung sind deaktiviert.',
                      style: TextStyle(fontSize: 13, height: 1.35, color: GrocifyTheme.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error == null ? 'Fehler: unbekannt' : 'Fehler: $error',
                      style: const TextStyle(fontSize: 12, height: 1.3, color: GrocifyTheme.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

