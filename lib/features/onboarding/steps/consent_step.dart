/// Consent Step - Rechtliche Einwilligungen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';
import '../models/user_profile_local.dart';
import '../../legal/presentation/legal_markdown_screen.dart';

class ConsentStep extends StatefulWidget {
  final UserProfileLocal profile;
  final Function(UserProfileLocal) onUpdate;
  final VoidCallback onNext;

  const ConsentStep({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<ConsentStep> createState() => _ConsentStepState();
}

class _ConsentStepState extends State<ConsentStep> {
  bool _acceptTerms = false;
  bool _acknowledgePrivacy = false;
  bool _analyticsOptIn = false;

  @override
  void initState() {
    super.initState();
    _analyticsOptIn = widget.profile.consentAnalyticsOptIn;
    // If consents were already given (e.g., during a reset and re-onboarding), pre-check them
    _acceptTerms = widget.profile.consentTermsAcceptedAt != null;
    _acknowledgePrivacy = widget.profile.consentPrivacyAckAt != null;
  }

  void _updateProfile() {
    final now = DateTime.now();
    widget.onUpdate(
      widget.profile.copyWith(
        consentTermsAcceptedAt: _acceptTerms ? now : null,
        consentPrivacyAckAt: _acknowledgePrivacy ? now : null,
        consentAnalyticsOptIn: _analyticsOptIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool allRequiredAccepted = _acceptTerms && _acknowledgePrivacy;
    
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GrocifyTheme.background,
              GrocifyTheme.background.withOpacity(0.96),
              GrocifyTheme.primary.withOpacity(0.10),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: GrocifyTheme.screenPadding,
                right: GrocifyTheme.screenPadding,
                top: GrocifyTheme.spaceXL,
                bottom: MediaQuery.of(context).viewInsets.bottom + GrocifyTheme.spaceLG,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - MediaQuery.of(context).viewInsets.bottom),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header (premium)
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: GrocifyTheme.surface,
                                borderRadius: BorderRadius.circular(GrocifyTheme.radiusXL),
                                border: Border.all(color: GrocifyTheme.border.withOpacity(0.65)),
                                boxShadow: GrocifyTheme.shadowMD,
                              ),
                              child: const Icon(Icons.verified_user_rounded, size: 34, color: GrocifyTheme.primary),
                            ),
                            const SizedBox(height: GrocifyTheme.spaceMD),
                            const Text(
                              'Deine Zustimmung',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: GrocifyTheme.textPrimary,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: GrocifyTheme.spaceSM),
                            Text(
                              'Damit sheap funktioniert (und rechtlich sauber ist), brauchen wir kurz dein OK.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: GrocifyTheme.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: GrocifyTheme.spaceXXL),

                      // Required
                      _SectionCard(
                        title: 'Pflicht',
                        subtitle: 'Ohne diese Zustimmung können wir dich nicht registrieren.',
                        child: Column(
                          children: [
                            _buildConsentCheckbox(
                              title: 'Ich akzeptiere die Nutzungsbedingungen',
                              value: _acceptTerms,
                              onChanged: (bool? value) {
                                setState(() {
                                  _acceptTerms = value ?? false;
                                });
                                _updateProfile();
                              },
                              isMandatory: true,
                              onTapLink: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LegalMarkdownScreen(
                                    title: 'AGB',
                                    assetPath: 'assets/legal/agb.md',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: GrocifyTheme.spaceMD),
                            _buildConsentCheckbox(
                              title: 'Ich habe die Datenschutzerklärung gelesen und verstanden',
                              value: _acknowledgePrivacy,
                              onChanged: (bool? value) {
                                setState(() {
                                  _acknowledgePrivacy = value ?? false;
                                });
                                _updateProfile();
                              },
                              isMandatory: true,
                              onTapLink: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LegalMarkdownScreen(
                                    title: 'Datenschutzerklärung',
                                    assetPath: 'assets/legal/datenschutz.md',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: GrocifyTheme.spaceLG),

                      // Optional
                      _SectionCard(
                        title: 'Optional',
                        subtitle: 'Hilft uns, sheap schneller besser zu machen.',
                        child: _buildConsentCheckbox(
                          title: 'Anonyme Nutzungsdaten und Absturzberichte senden (optional)',
                          value: _analyticsOptIn,
                          onChanged: (bool? value) {
                            setState(() {
                              _analyticsOptIn = value ?? false;
                            });
                            _updateProfile();
                          },
                          isMandatory: false,
                          infoText:
                              'Wir speichern keine Klar-Namen. Du kannst das jederzeit in den Einstellungen ändern.',
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: GrocifyTheme.spaceLG),

                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: allRequiredAccepted
                              ? () {
                                  _updateProfile();
                                  HapticFeedback.mediumImpact();
                                  widget.onNext();
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceLG),
                          ),
                          child: const Text(
                            'Weiter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: GrocifyTheme.spaceLG),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConsentCheckbox({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool isMandatory,
    VoidCallback? onTapLink,
    String? infoText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GrocifyTheme.border.withOpacity(0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Checkbox(
                      value: value,
                      onChanged: onChanged,
                      activeColor: GrocifyTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: GrocifyTheme.textPrimary,
                          height: 1.25,
                        ),
                        children: [
                          if (isMandatory)
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (onTapLink != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onTapLink,
                      child: const Text('Ansehen'),
                    ),
                  ],
                ],
              ),
              if (infoText != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Text(
                    infoText,
                    style: TextStyle(
                      fontSize: 13,
                      color: GrocifyTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusXL),
        border: Border.all(color: GrocifyTheme.border.withOpacity(0.60)),
        boxShadow: GrocifyTheme.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: GrocifyTheme.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: GrocifyTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: GrocifyTheme.spaceLG),
          child,
        ],
      ),
    );
  }
}
