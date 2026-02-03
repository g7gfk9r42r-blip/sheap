import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/grocify_theme.dart';
import '../data/auth_service_local.dart';

enum _AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const AuthScreen({super.key, required this.onSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthMode _mode = _AuthMode.login;
  bool _busy = false;
  bool _showPassword = false;
  bool _acceptConsent = false;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  String _diet = 'none';
  final _allergensCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    _nameCtrl.dispose();
    _allergensCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (_mode == _AuthMode.register && !_acceptConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Datenschutz & AGB akzeptieren.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (_mode == _AuthMode.login) {
        await AuthServiceLocal.instance.login(email: _emailCtrl.text, password: _pwCtrl.text);
      } else {
        final allergens = _allergensCtrl.text
            .split(RegExp(r'[,;]'))
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toList();

        await AuthServiceLocal.instance.register(
          email: _emailCtrl.text,
          password: _pwCtrl.text,
          confirmPassword: _pw2Ctrl.text,
          displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          diet: _diet,
          allergies: allergens.isEmpty ? null : allergens,
          goals: null,
          acceptPrivacyAndTerms: _acceptConsent,
        );
      }

      HapticFeedback.mediumImpact();
      widget.onSuccess();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final res = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Passwort zurücksetzen'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E‑Mail'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Senden')),
        ],
      ),
    );
    if (res == null || res.isEmpty) return;
    try {
      await AuthServiceLocal.instance.requestPasswordResetStub(res);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset-Link angefordert (lokaler Stub).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _AuthMode.register;

    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: GrocifyTheme.shadowMD,
                            border: Border.all(color: GrocifyTheme.border.withOpacity(0.55)),
                          ),
                          child: Image.asset(
                            'assets/Logo Jawoll/logo.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'sheap',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: GrocifyTheme.textPrimary,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isRegister ? 'Erstelle deinen Account' : 'Willkommen zurück',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: GrocifyTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  CupertinoSlidingSegmentedControl<_AuthMode>(
                    groupValue: _mode,
                    children: const {
                      _AuthMode.login: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Anmelden')),
                      _AuthMode.register: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Registrieren')),
                    },
                    onValueChanged: (v) {
                      if (_busy) return;
                      if (v == null) return;
                      setState(() {
                        _mode = v;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GrocifyTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GrocifyTheme.border.withOpacity(0.60)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EmailField(controller: _emailCtrl),
                          const SizedBox(height: 12),
                          _PasswordField(
                            controller: _pwCtrl,
                            label: 'Passwort',
                            show: _showPassword,
                            onToggle: () => setState(() => _showPassword = !_showPassword),
                          ),
                          if (isRegister) ...[
                            const SizedBox(height: 12),
                            _PasswordField(
                              controller: _pw2Ctrl,
                              label: 'Passwort bestätigen',
                              show: false,
                              onToggle: null,
                              validateConfirmAgainst: _pwCtrl,
                            ),
                            const SizedBox(height: 12),
                            _TextField(
                              controller: _nameCtrl,
                              label: 'Name (optional)',
                              icon: Icons.person_outline_rounded,
                              validator: (_) => null,
                            ),
                            const SizedBox(height: 12),
                            _DietField(
                              value: _diet,
                              onChanged: (v) => setState(() => _diet = v),
                            ),
                            const SizedBox(height: 12),
                            _TextField(
                              controller: _allergensCtrl,
                              label: 'Allergene (optional, kommagetrennt)',
                              icon: Icons.warning_amber_rounded,
                              validator: (_) => null,
                            ),
                            const SizedBox(height: 12),
                            _ConsentRow(
                              value: _acceptConsent,
                              onChanged: _busy ? null : (v) => setState(() => _acceptConsent = v),
                            ),
                          ],

                          if (!isRegister) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy ? null : _forgotPassword,
                                child: const Text('Passwort vergessen?'),
                              ),
                            ),
                          ],

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
                                  : Text(
                                      isRegister ? 'Registrieren' : 'Anmelden',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Hinweis: Datenschutz/AGB werden technisch lokal gespeichert. Inhalte werden als MUSTER angezeigt (juristisch prüfen).',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: GrocifyTheme.textTertiary, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _ConsentRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Checkbox(value: value, onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false)),
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
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  const _EmailField({required this.controller});

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  Widget build(BuildContext context) {
    return _TextField(
      controller: controller,
      label: 'E‑Mail',
      icon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return 'Bitte E‑Mail eingeben';
        if (!_emailRegex.hasMatch(s)) return 'Ungültige E‑Mail';
        return null;
      },
    );
  }
}

class _DietField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DietField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Ernährung (optional)',
        prefixIcon: const Icon(Icons.restaurant_rounded),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'none', child: Text('Keine')),
            DropdownMenuItem(value: 'vegetarian', child: Text('Vegetarisch')),
            DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
            DropdownMenuItem(value: 'lowcarb', child: Text('Low Carb')),
            DropdownMenuItem(value: 'omnivore', child: Text('Omnivor')),
          ],
          onChanged: (v) => onChanged(v ?? 'none'),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback? onToggle;
  final TextEditingController? validateConfirmAgainst;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    this.validateConfirmAgainst,
  });

  @override
  Widget build(BuildContext context) {
    return _TextField(
      controller: controller,
      label: label,
      icon: Icons.lock_outline_rounded,
      obscureText: !show,
      suffix: onToggle == null
          ? null
          : IconButton(
              onPressed: onToggle,
              icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            ),
      validator: (v) {
        final s = (v ?? '');
        if (s.length < 8) return 'Mindestens 8 Zeichen';
        if (validateConfirmAgainst != null && s != validateConfirmAgainst!.text) return 'Passwörter stimmen nicht überein';
        return null;
      },
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?) validator;

  const _TextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}


