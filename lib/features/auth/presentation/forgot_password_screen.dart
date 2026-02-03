import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/grocify_theme.dart';
import '../data/auth_service_local.dart';
import 'auth_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onGoBack;

  const ForgotPasswordScreen({
    super.key,
    required this.onGoBack,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _success = null;
    });
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await AuthServiceLocal.instance.requestPasswordResetStub(_emailCtrl.text);
      HapticFeedback.mediumImpact();
      setState(() => _success = 'Wenn ein Account existiert, wurde eine Reset‑E‑Mail gesendet.');
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
      subtitle: 'Passwort zurücksetzen',
      footer: TextButton(
        onPressed: _busy ? null : widget.onGoBack,
        child: const Text('Zurück'),
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
            if (_success != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GrocifyTheme.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GrocifyTheme.success.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: GrocifyTheme.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _success!,
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
                    : const Text('Reset‑E‑Mail senden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


