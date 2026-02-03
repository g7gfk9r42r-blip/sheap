import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/grocify_theme.dart';
import '../data/auth_service_local.dart';
import 'auth_ui.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onGoLogin;

  const RegisterScreen({
    super.key,
    required this.onGoLogin,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  bool _acceptConsent = false;
  String? _error;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (!_acceptConsent) {
      setState(() => _error = 'Bitte Datenschutz & AGB akzeptieren, um dich zu registrieren.');
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthServiceLocal.instance.register(
        email: _emailCtrl.text,
        password: _pwCtrl.text,
        confirmPassword: _pw2Ctrl.text,
        displayName: null,
        diet: null,
        goals: null,
        allergies: null,
        acceptPrivacyAndTerms: _acceptConsent,
      );
      HapticFeedback.mediumImpact();
      // AuthGate will switch to VerifyEmailScreen automatically.
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = e.toString().replaceFirst('StateError: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'sheap',
      subtitle: 'Erstelle deinen Account',
      footer: Column(
        children: [
          Text(
            'Schon registriert?',
            style: TextStyle(color: GrocifyTheme.textSecondary.withOpacity(0.9), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy ? null : widget.onGoLogin,
            child: const Text('Zurück zum Login'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AuthInlineError(message: _error!),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: authFieldDecoration(label: 'E‑Mail', icon: Icons.mail_outline_rounded),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Bitte E‑Mail eingeben';
                if (!_emailRegex.hasMatch(s)) return 'Ungültige E‑Mail';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pwCtrl,
              obscureText: !_showPassword,
              decoration: authFieldDecoration(
                label: 'Passwort',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  onPressed: _busy ? null : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
              ),
              validator: (v) {
                final s = (v ?? '');
                if (s.length < 8) return 'Mindestens 8 Zeichen';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pw2Ctrl,
              obscureText: true,
              decoration: authFieldDecoration(label: 'Passwort bestätigen', icon: Icons.lock_outline_rounded),
              validator: (v) {
                final s = (v ?? '');
                if (s.length < 8) return 'Mindestens 8 Zeichen';
                if (s != _pwCtrl.text) return 'Passwörter stimmen nicht überein';
                return null;
              },
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: _busy ? null : () => setState(() => _acceptConsent = !_acceptConsent),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Checkbox(
                      value: _acceptConsent,
                      onChanged: _busy ? null : (v) => setState(() => _acceptConsent = v ?? false),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ich akzeptiere Datenschutz & AGB',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GrocifyTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
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
                    : const Text('Registrieren', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nach der Registrierung senden wir dir automatisch eine Verifizierungs‑E‑Mail. Ohne Verifizierung kommst du nicht in die App.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: GrocifyTheme.textTertiary, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}


