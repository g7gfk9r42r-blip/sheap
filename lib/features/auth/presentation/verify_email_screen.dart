import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/grocify_theme.dart';
import '../data/auth_service_local.dart';
import 'auth_ui.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _busy = false;
  String? _error;
  String? _info;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  void _startCooldown([int seconds = 30]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final next = _cooldownSeconds - 1;
      setState(() => _cooldownSeconds = next.clamp(0, 9999));
      if (_cooldownSeconds <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
      _busy = true;
    });
    try {
      final u = _user;
      if (u == null) {
        setState(() => _error = 'Session abgelaufen. Bitte erneut anmelden.');
        return;
      }
      await u.sendEmailVerification();
      HapticFeedback.mediumImpact();
      setState(() => _info = 'Verifizierungs‑E‑Mail wurde erneut gesendet.');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = e.message ?? 'Senden fehlgeschlagen.');
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Senden fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _error = null;
      _info = null;
      _busy = true;
    });
    try {
      final u = _user;
      if (u == null) {
        setState(() => _error = 'Session abgelaufen. Bitte erneut anmelden.');
        return;
      }
      await u.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        HapticFeedback.mediumImpact();
        setState(() => _info = 'E‑Mail verifiziert. Du wirst jetzt weitergeleitet …');
        return;
      }
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Noch nicht verifiziert. Bitte bestätige die E‑Mail und versuche es erneut.');
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Konnte Status nicht prüfen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _error = null;
      _info = null;
      _busy = true;
    });
    try {
      await AuthServiceLocal.instance.logout();
      HapticFeedback.mediumImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Logout fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final email = (u?.email ?? '').trim();

    return AuthScaffold(
      title: 'sheap',
      subtitle: 'E‑Mail verifizieren',
      footer: TextButton(
        onPressed: _busy ? null : _logout,
        child: const Text('Abmelden'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AuthInlineError(message: _error!),
            const SizedBox(height: 12),
          ],
          if (_info != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GrocifyTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GrocifyTheme.primary.withOpacity(0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: GrocifyTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _info!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: GrocifyTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Du musst deine E‑Mail bestätigen, bevor du die App nutzen kannst.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GrocifyTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            email.isEmpty ? 'E‑Mail: —' : 'E‑Mail: $email',
            style: const TextStyle(fontSize: 13, color: GrocifyTheme.textSecondary, height: 1.25),
          ),
          const SizedBox(height: 12),
          const Text(
            'Öffne dein Postfach und klicke den Link in der Verifizierungs‑E‑Mail. Danach klicke hier auf „Ich habe verifiziert“.',
            style: TextStyle(fontSize: 12, color: GrocifyTheme.textTertiary, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _checkVerified,
              style: FilledButton.styleFrom(
                backgroundColor: GrocifyTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Ich habe verifiziert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: (_busy || _cooldownSeconds > 0) ? null : _resend,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: GrocifyTheme.border.withOpacity(0.9)),
              ),
              child: Text(
                _cooldownSeconds > 0 ? 'Erneut senden (${_cooldownSeconds}s)' : 'Erneut senden',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


