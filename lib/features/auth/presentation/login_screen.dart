import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/grocify_theme.dart';
import '../data/auth_service_local.dart';
import 'auth_ui.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onGoRegister;
  final VoidCallback onGoForgotPassword;

  const LoginScreen({
    super.key,
    required this.onGoRegister,
    required this.onGoForgotPassword,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await AuthServiceLocal.instance.login(email: _emailCtrl.text, password: _pwCtrl.text);
      HapticFeedback.mediumImpact();
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
      subtitle: 'Willkommen zurück',
      footer: Column(
        children: [
          Text(
            'Noch keinen Account?',
            style: TextStyle(color: GrocifyTheme.textSecondary.withOpacity(0.9), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy ? null : widget.onGoRegister,
            child: const Text('Jetzt registrieren'),
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
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : widget.onGoForgotPassword,
                child: const Text('Passwort vergessen?'),
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
                    : const Text('Anmelden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


