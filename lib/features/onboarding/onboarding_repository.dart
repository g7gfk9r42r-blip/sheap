/// Onboarding Repository - Persistiert Onboarding-Status und User Profile
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_profile_local.dart';
import '../../core/config/app_privacy_config.dart';

class OnboardingRepository {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyUserProfile = 'user_profile_local';
  static UserProfileLocal? _memoryProfile;
  static bool? _memoryOnboardingCompleted;

  /// Prüft ob Onboarding bereits abgeschlossen wurde
  static Future<bool> isOnboardingCompleted() async {
    if (!AppPrivacyConfig.persistUserProfileLocal) {
      return _memoryOnboardingCompleted ?? false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingCompleted) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Markiert Onboarding als abgeschlossen
  static Future<void> setOnboardingCompleted(bool completed) async {
    if (!AppPrivacyConfig.persistUserProfileLocal) {
      _memoryOnboardingCompleted = completed;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, completed);
    } catch (e) {
      // Ignore
    }
  }

  /// Speichert User Profile
  static Future<void> saveUserProfile(UserProfileLocal profile) async {
    if (!AppPrivacyConfig.persistUserProfileLocal) {
      // Keep only consents in memory; drop personal fields.
      _memoryProfile = UserProfileLocal(
        waterGoalMl: profile.waterGoalMl,
        consentTermsAcceptedAt: profile.consentTermsAcceptedAt,
        consentPrivacyAckAt: profile.consentPrivacyAckAt,
        consentAnalyticsOptIn: profile.consentAnalyticsOptIn,
        deviceLocale: profile.deviceLocale,
        appVersion: profile.appVersion,
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      // Local-first: persist the full local profile (user preferences).
      final jsonString = json.encode(profile.toJson());
      await prefs.setString(_keyUserProfile, jsonString);
    } catch (e) {
      // Ignore
    }
  }

  /// Lädt User Profile
  static Future<UserProfileLocal?> loadUserProfile() async {
    if (!AppPrivacyConfig.persistUserProfileLocal) {
      return _memoryProfile;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyUserProfile);
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfileLocal.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Löscht alle Daten (inkl. Onboarding-Status)
  static Future<void> deleteAllData() async {
    _memoryProfile = null;
    _memoryOnboardingCompleted = false;
    if (!AppPrivacyConfig.persistUserProfileLocal) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserProfile);
      await prefs.setBool(_keyOnboardingCompleted, false);
    } catch (e) {
      // Ignore
    }
  }

  /// Exportiert User Profile als JSON-String
  static Future<String?> exportUserProfile() async {
    try {
      final profile = await loadUserProfile();
      if (profile == null) return null;
      return json.encode(profile.toJson());
    } catch (e) {
      return null;
    }
  }
}

