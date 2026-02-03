/// Privacy Settings Screen - Datenschutz-Einstellungen
import 'package:flutter/material.dart';
import '../../../core/theme/grocify_theme.dart';
import '../../onboarding/onboarding_repository.dart';
import '../../privacy/consent_manager.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _analyticsOptIn = false;
  Map<String, dynamic>? _consentStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsentStatus();
  }

  Future<void> _loadConsentStatus() async {
    setState(() => _isLoading = true);
    final status = await ConsentManager.getConsentStatus();
    if (mounted) {
      setState(() {
        _consentStatus = status;
        _analyticsOptIn = status['analyticsOptIn'] as bool? ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAnalyticsOptIn(bool value) async {
    await ConsentManager.updateConsents(analyticsOptIn: value);
    await _loadConsentStatus();
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Daten löschen'),
        content: const Text(
          'Möchtest du wirklich alle deine Daten löschen? Diese Aktion kann nicht rückgängig gemacht werden.\n\n'
          'Die App wird auf den Ausgangszustand zurückgesetzt und du wirst erneut durch das Onboarding geführt.',
        ),
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
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await OnboardingRepository.deleteAllData();
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        // App will restart to onboarding
      }
    }
  }

  Future<void> _exportData() async {
    final jsonData = await OnboardingRepository.exportUserProfile();
    
    if (!mounted) return;
    
    if (jsonData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Daten zum Exportieren vorhanden.'),
          backgroundColor: GrocifyTheme.textSecondary,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daten exportieren'),
        content: SingleChildScrollView(
          child: SelectableText(
            jsonData,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: const Text(
          'Datenschutz-Einstellungen',
          style: TextStyle(
            color: GrocifyTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: GrocifyTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Analytics Toggle
                    _buildSection(
                      title: 'Einwilligungen',
                      children: [
                        Container(
                          padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
                          decoration: BoxDecoration(
                            color: GrocifyTheme.surface,
                            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
                            border: Border.all(color: GrocifyTheme.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Analytics & Crash-Reports',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: GrocifyTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hilft uns, Fehler zu finden und die App zu verbessern',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: GrocifyTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _analyticsOptIn,
                                onChanged: (value) {
                                  _updateAnalyticsOptIn(value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXXL),
                    
                    // Consent Status
                    if (_consentStatus != null)
                      _buildSection(
                        title: 'Einwilligungsstatus',
                        children: [
                          Container(
                            padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
                            decoration: BoxDecoration(
                              color: GrocifyTheme.surfaceSubtle,
                              borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildConsentStatusItem(
                                  'Nutzungsbedingungen',
                                  _consentStatus!['termsAccepted'] as bool,
                                  _consentStatus!['termsAcceptedAt'] as String?,
                                ),
                                const Divider(),
                                _buildConsentStatusItem(
                                  'Datenschutzerklärung',
                                  _consentStatus!['privacyAcknowledged'] as bool,
                                  _consentStatus!['privacyAckAt'] as String?,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXXL),
                    
                    // Data Actions
                    _buildSection(
                      title: 'Datenverwaltung',
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(GrocifyTheme.spaceLG),
                          leading: const Icon(Icons.download_rounded, color: GrocifyTheme.textPrimary),
                          title: const Text(
                            'Meine Daten exportieren',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: GrocifyTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Exportiere deine gespeicherten Daten als JSON',
                            style: TextStyle(
                              fontSize: 13,
                              color: GrocifyTheme.textSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: GrocifyTheme.textSecondary),
                          onTap: _exportData,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.all(GrocifyTheme.spaceLG),
                          leading: const Icon(Icons.delete_forever_rounded, color: GrocifyTheme.error),
                          title: const Text(
                            'Alle Daten löschen',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: GrocifyTheme.error,
                            ),
                          ),
                          subtitle: Text(
                            'Löscht alle lokalen Daten und setzt die App zurück',
                            style: TextStyle(
                              fontSize: 13,
                              color: GrocifyTheme.textSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: GrocifyTheme.textSecondary),
                          onTap: _deleteAllData,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXXL),
                    
                    // Info
                    Container(
                      padding: const EdgeInsets.all(GrocifyTheme.spaceMD),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: GrocifyTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: GrocifyTheme.spaceSM),
                          Expanded(
                            child: Text(
                              'Alle Daten werden lokal auf deinem Gerät gespeichert. Es erfolgt keine Übertragung an externe Server.',
                              style: TextStyle(
                                fontSize: 13,
                                color: GrocifyTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: GrocifyTheme.textPrimary,
          ),
        ),
        const SizedBox(height: GrocifyTheme.spaceMD),
        Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
            boxShadow: GrocifyTheme.shadowSM,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildConsentStatusItem(String label, bool accepted, String? timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceSM),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accepted ? GrocifyTheme.success : GrocifyTheme.error,
            size: 20,
          ),
          const SizedBox(width: GrocifyTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GrocifyTheme.textPrimary,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Am ${DateTime.parse(timestamp).toString().split(' ')[0]}',
                    style: TextStyle(
                      fontSize: 12,
                      color: GrocifyTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

