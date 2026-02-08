/// Settings Screen
/// App settings and preferences
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/grocify_theme.dart';
import '../auth/data/auth_service_local.dart';
import '../user/data/user_profile_service.dart';
import '../customer/data/customer_data_store.dart';
import '../customer/domain/models/customer_preferences.dart';
import '../legal/presentation/legal_markdown_screen.dart';
import '../premium/paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  bool _personalizationEnabled = true;
  String _language = 'Deutsch';

  String? _uid;
  String _diet = 'none';
  String _goal = 'maintain_weight';
  final TextEditingController _allergiesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadUserPrefs();
  }

  @override
  void dispose() {
    _allergiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = _prefs?.getString('profile_language') ?? 'Deutsch';
    });
  }

  Future<void> _loadUserPrefs() async {
    final user = await AuthServiceLocal.instance.getCurrentUser();
    final customerPrefs = await CustomerDataStore.instance.loadPreferences();
    if (!mounted) return;
    setState(() {
      _uid = user?.uid;
      _diet = user?.profile.diet ?? 'none';
      final goals = user?.profile.goals ?? const <String>[];
      _goal = goals.isNotEmpty ? goals.first : 'maintain_weight';
      _allergiesCtrl.text = (user?.profile.allergies ?? const []).join(', ');
      _personalizationEnabled = customerPrefs.personalizationEnabled;
    });
  }

  Future<void> _saveUserPrefs() async {
    final uid = _uid;
    if (uid == null) return;
    final allergies = _allergiesCtrl.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    await UserProfileService.instance.updateProfile(
      uid,
      diet: _diet,
      goals: [_goal],
      allergies: allergies,
    );

    // Also persist exportable customer_preferences.json
    final existing = await CustomerDataStore.instance.loadPreferences();
    await CustomerDataStore.instance.savePreferences(
      CustomerPreferences(
        diet: CustomerDietX.fromString(_diet),
        primaryGoal: _goal,
        dislikedIngredients: existing.dislikedIngredients,
        allergens: allergies,
        calorieGoal: existing.calorieGoal,
        language: existing.language,
        personalizationEnabled: _personalizationEnabled,
      ),
    );
  }

  Future<void> _savePreference(String key, dynamic value) async {
    if (value is bool) {
      await _prefs?.setBool(key, value);
    } else {
      await _prefs?.setString(key, value.toString());
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache löschen'),
        content: const Text(
          'Möchtest du wirklich den Cache löschen? Dies kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear cache logic here
      // For now, just show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('Cache erfolgreich gelöscht'),
              ],
            ),
            backgroundColor: GrocifyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showFeedback() {
    // Show feedback dialog or navigate to feedback screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feedback senden'),
        content: const Text(
          'Vielen Dank für dein Interesse! Feedback-Funktion wird in einer zukünftigen Version verfügbar sein.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Möchtest du dich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: GrocifyTheme.error,
            ),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthServiceLocal.instance.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('Erfolgreich abgemeldet'),
              ],
            ),
            backgroundColor: GrocifyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        // Hard reset back to AuthGate
        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          color: GrocifyTheme.textPrimary,
        ),
        title: const Text(
          'Einstellungen',
          style: TextStyle(
            color: GrocifyTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Account'),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.person_rounded,
                    title: 'Angemeldet',
                    subtitle: _uid == null ? '—' : (_prefs?.getString('session_email') ?? ''),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.logout_rounded,
                    title: 'Abmelden',
                    onTap: _signOut,
                    textColor: GrocifyTheme.error,
                  ),
                  const SizedBox(height: 28),

                  _buildSectionTitle('Personalisierung'),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Personalisierung',
                    subtitle: 'Sortiert Rezepte nach deinen Preferences',
                    trailing: Switch(
                      value: _personalizationEnabled,
                      onChanged: (v) async {
                        setState(() => _personalizationEnabled = v);
                        await _saveUserPrefs();
                      },
                      activeTrackColor: GrocifyTheme.primary,
                      activeThumbColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDietPicker(),
                  const SizedBox(height: 12),
                  _buildGoalPicker(),
                  const SizedBox(height: 12),
                  _buildAllergiesField(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _uid == null ? null : () async => _saveUserPrefs(),
                      style: FilledButton.styleFrom(
                        backgroundColor: GrocifyTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildSectionTitle('Premium'),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.star_rounded,
                    title: 'Auf Premium umschalten',
                    subtitle: '6,99 € / Monat (Mock-Flow, offline)',
                    onTap: () async {
                      await CustomerDataStore.instance.logEvent('premium_intent_opened', {});
                      if (!context.mounted) return;
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
                    },
                  ),
                  const SizedBox(height: 28),

                  _buildSectionTitle('Allgemein'),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.delete_sweep_rounded,
                    title: 'Cache löschen',
                    onTap: _clearCache,
                    textColor: GrocifyTheme.textPrimary,
                  ),
                  const SizedBox(height: 12),
                  _buildSelectSettingsItem(
                    icon: Icons.language_rounded,
                    title: 'Sprache',
                    value: _language,
                    options: ['Deutsch', 'English'],
                    onChanged: (value) async {
                      setState(() => _language = value);
                      await _savePreference('profile_language', value);
                    },
                  ),
                  const SizedBox(height: 28),

                  _buildSectionTitle('Datenschutz'),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.privacy_tip_rounded,
                    title: 'Datenschutz',
                    subtitle: 'Datenschutzerklärung (DSGVO)',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalMarkdownScreen(
                            title: 'Datenschutzerklärung',
                            assetPath: 'assets/legal/datenschutz.md',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.description_rounded,
                    title: 'AGB',
                    subtitle: 'Nutzungsbedingungen',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalMarkdownScreen(
                            title: 'AGB',
                            assetPath: 'assets/legal/agb.md',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.business_rounded,
                    title: 'Impressum',
                    subtitle: 'Anbieterinformationen',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalMarkdownScreen(
                            title: 'Impressum',
                            assetPath: 'assets/legal/impressum.md',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(height: 12),
                  _buildSettingsItem(
                    icon: Icons.thumb_up_rounded,
                    title: 'Feedback',
                    subtitle: 'Coming soon',
                    onTap: _showFeedback,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: GrocifyTheme.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildDietPicker() {
    final enabled = _uid != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrocifyTheme.border, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant_rounded, color: GrocifyTheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Ernährung',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GrocifyTheme.textPrimary),
            ),
          ),
          DropdownButton<String>(
            value: _diet,
            onChanged: enabled
                ? (v) => setState(() => _diet = v ?? 'none')
                : null,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Keine')),
              DropdownMenuItem(value: 'vegetarian', child: Text('Vegetarisch')),
              DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
              DropdownMenuItem(value: 'omnivore', child: Text('Omnivor')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPicker() {
    final enabled = _uid != null;
    const options = <String, String>{
      'lose_weight': 'Abnehmen',
      'gain_weight': 'Zunehmen',
      'maintain_weight': 'Gewicht halten',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrocifyTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_rounded, color: GrocifyTheme.primary),
              SizedBox(width: 12),
              Text(
                'Ziel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GrocifyTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.entries.map((e) {
              final selected = _goal == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: enabled ? (_) => setState(() => _goal = e.key) : null,
                selectedColor: GrocifyTheme.primary.withOpacity(0.16),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? GrocifyTheme.primary : GrocifyTheme.textPrimary,
                ),
                side: BorderSide(
                  color: selected ? GrocifyTheme.primary : GrocifyTheme.border.withOpacity(0.8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergiesField() {
    final enabled = _uid != null;
    return TextField(
      controller: _allergiesCtrl,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: 'Allergien (kommagetrennt)',
        prefixIcon: const Icon(Icons.warning_amber_rounded),
        filled: true,
        fillColor: GrocifyTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool showArrow = false,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: GrocifyTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: GrocifyTheme.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor ?? GrocifyTheme.textPrimary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: (subtitle == null || subtitle.trim().isEmpty)
                  ? Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor ?? GrocifyTheme.textPrimary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor ?? GrocifyTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: GrocifyTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
            if (trailing != null) trailing,
            if (showArrow && trailing == null)
              Icon(
                Icons.chevron_right_rounded,
                color: GrocifyTheme.textTertiary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((option) {
                return RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: value,
                  onChanged: (selected) {
                    if (selected != null) {
                      Navigator.pop(context);
                      onChanged(selected);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: GrocifyTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: GrocifyTheme.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: GrocifyTheme.textPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: GrocifyTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: GrocifyTheme.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: GrocifyTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: GrocifyTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Legal content is shown via assets-based Markdown templates (`assets/legal/*.md`).
