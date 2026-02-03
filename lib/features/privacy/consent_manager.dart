/// Consent Manager - Verwaltet Einwilligungen rechtssicher
import '../onboarding/onboarding_repository.dart';

class ConsentManager {
  ConsentManager._();

  /// Aktualisiert Consent-Status
  static Future<void> updateConsents({
    bool? termsAccepted,
    bool? privacyAcknowledged,
    bool? analyticsOptIn,
  }) async {
    final profile = await OnboardingRepository.loadUserProfile();
    if (profile == null) return;

    final updated = profile.copyWith(
      consentTermsAcceptedAt: termsAccepted == true ? DateTime.now() : profile.consentTermsAcceptedAt,
      consentPrivacyAckAt: privacyAcknowledged == true ? DateTime.now() : profile.consentPrivacyAckAt,
      consentAnalyticsOptIn: analyticsOptIn ?? profile.consentAnalyticsOptIn,
    );

    await OnboardingRepository.saveUserProfile(updated);
  }

  /// Prüft ob Consents vorhanden sind
  static Future<bool> hasRequiredConsents() async {
    final profile = await OnboardingRepository.loadUserProfile();
    if (profile == null) return false;

    return profile.consentTermsAcceptedAt != null &&
           profile.consentPrivacyAckAt != null;
  }

  /// Gibt aktuellen Consent-Status zurück
  static Future<Map<String, dynamic>> getConsentStatus() async {
    final profile = await OnboardingRepository.loadUserProfile();
    if (profile == null) {
      return {
        'termsAccepted': false,
        'privacyAcknowledged': false,
        'analyticsOptIn': false,
      };
    }

    return {
      'termsAccepted': profile.consentTermsAcceptedAt != null,
      'privacyAcknowledged': profile.consentPrivacyAckAt != null,
      'analyticsOptIn': profile.consentAnalyticsOptIn,
      'termsAcceptedAt': profile.consentTermsAcceptedAt?.toIso8601String(),
      'privacyAckAt': profile.consentPrivacyAckAt?.toIso8601String(),
    };
  }
}

