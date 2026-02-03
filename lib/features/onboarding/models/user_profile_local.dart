/// User Profile Local - Lokale Nutzerdaten
enum GoalType {
  loseWeight, // Abnehmen
  maintainWeight, // Halten
  gainWeight, // Zunehmen
}

enum DietPreference {
  vegetarian,
  vegan,
  lowCarb,
  highProtein,
  lactoseFree,
  glutenFree,
}

class UserProfileLocal {
  // Persönliche Daten
  final String? name; // Name für persönliche Ansprache
  
  // Gewichts-Ziele (optional)
  final double? startWeight;
  final double? targetWeight;
  final GoalType? goalType;

  // Wasserziel
  final double waterGoalMl;

  // Ernährung & Präferenzen
  final Set<DietPreference> dietPreferences;
  final String? allergies; // Freie Texteingabe

  // Kochzeit-Präferenz (in Minuten)
  final int? preferredCookingTime; // 10-20, 20-40, 40+

  // Supermarkt (optional)
  // Multiple favorites (optional)
  final List<String> favoriteSupermarkets;
  // Legacy single value (kept for backward compatibility)
  final String? preferredSupermarket;

  // Consents (Timestamps für rechtliche Nachweisbarkeit)
  final DateTime? consentTermsAcceptedAt;
  final DateTime? consentPrivacyAckAt;
  final bool consentAnalyticsOptIn;

  // Meta-Daten (optional)
  final String? deviceLocale;
  final String? appVersion;

  UserProfileLocal({
    this.name,
    this.startWeight,
    this.targetWeight,
    this.goalType,
    required this.waterGoalMl,
    this.dietPreferences = const {},
    this.allergies,
    this.preferredCookingTime,
    this.favoriteSupermarkets = const [],
    this.preferredSupermarket,
    this.consentTermsAcceptedAt,
    this.consentPrivacyAckAt,
    this.consentAnalyticsOptIn = false,
    this.deviceLocale,
    this.appVersion,
  });

  // JSON Serialization
  Map<String, dynamic> toJson() {
    final fav = favoriteSupermarkets;
    return {
      'name': name,
      'startWeight': startWeight,
      'targetWeight': targetWeight,
      'goalType': goalType?.name,
      'waterGoalMl': waterGoalMl,
      'dietPreferences': dietPreferences.map((e) => e.name).toList(),
      'allergies': allergies,
      'preferredCookingTime': preferredCookingTime,
      'favoriteSupermarkets': fav,
      'preferredSupermarket': preferredSupermarket,
      'consentTermsAcceptedAt': consentTermsAcceptedAt?.toIso8601String(),
      'consentPrivacyAckAt': consentPrivacyAckAt?.toIso8601String(),
      'consentAnalyticsOptIn': consentAnalyticsOptIn,
      'deviceLocale': deviceLocale,
      'appVersion': appVersion,
    };
  }

  factory UserProfileLocal.fromJson(Map<String, dynamic> json) {
    final favRaw = json['favoriteSupermarkets'];
    final fav = (favRaw is List)
        ? favRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
        : <String>[];
    final legacySingle = json['preferredSupermarket'] as String?;
    final mergedFav = fav.isNotEmpty
        ? fav
        : ((legacySingle ?? '').trim().isEmpty ? <String>[] : <String>[legacySingle!.trim()]);
    return UserProfileLocal(
      name: json['name'] as String?,
      startWeight: json['startWeight'] as double?,
      targetWeight: json['targetWeight'] as double?,
      goalType: json['goalType'] != null
          ? GoalType.values.firstWhere(
              (e) => e.name == json['goalType'],
              orElse: () => GoalType.maintainWeight,
            )
          : null,
      waterGoalMl: (json['waterGoalMl'] as num?)?.toDouble() ?? 2000.0,
      dietPreferences: (json['dietPreferences'] as List<dynamic>?)
              ?.map((e) => DietPreference.values.firstWhere(
                    (pref) => pref.name == e,
                    orElse: () => DietPreference.vegetarian,
                  ))
              .toSet() ??
          {},
      allergies: json['allergies'] as String?,
      preferredCookingTime: json['preferredCookingTime'] as int?,
      favoriteSupermarkets: mergedFav,
      preferredSupermarket: legacySingle,
      consentTermsAcceptedAt: json['consentTermsAcceptedAt'] != null
          ? DateTime.parse(json['consentTermsAcceptedAt'])
          : null,
      consentPrivacyAckAt: json['consentPrivacyAckAt'] != null
          ? DateTime.parse(json['consentPrivacyAckAt'])
          : null,
      consentAnalyticsOptIn: json['consentAnalyticsOptIn'] as bool? ?? false,
      deviceLocale: json['deviceLocale'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }

  UserProfileLocal copyWith({
    String? name,
    double? startWeight,
    double? targetWeight,
    GoalType? goalType,
    double? waterGoalMl,
    Set<DietPreference>? dietPreferences,
    String? allergies,
    int? preferredCookingTime,
    List<String>? favoriteSupermarkets,
    String? preferredSupermarket,
    DateTime? consentTermsAcceptedAt,
    DateTime? consentPrivacyAckAt,
    bool? consentAnalyticsOptIn,
    String? deviceLocale,
    String? appVersion,
  }) {
    return UserProfileLocal(
      name: name ?? this.name,
      startWeight: startWeight ?? this.startWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      goalType: goalType ?? this.goalType,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      dietPreferences: dietPreferences ?? this.dietPreferences,
      allergies: allergies ?? this.allergies,
      preferredCookingTime: preferredCookingTime ?? this.preferredCookingTime,
      favoriteSupermarkets: favoriteSupermarkets ?? this.favoriteSupermarkets,
      preferredSupermarket: preferredSupermarket ?? this.preferredSupermarket,
      consentTermsAcceptedAt: consentTermsAcceptedAt ?? this.consentTermsAcceptedAt,
      consentPrivacyAckAt: consentPrivacyAckAt ?? this.consentPrivacyAckAt,
      consentAnalyticsOptIn: consentAnalyticsOptIn ?? this.consentAnalyticsOptIn,
      deviceLocale: deviceLocale ?? this.deviceLocale,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}
