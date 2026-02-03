import 'dart:convert';

class UserFlags {
  final bool isPremium;
  final bool welcomeSeen;

  const UserFlags({this.isPremium = false, this.welcomeSeen = false});

  Map<String, dynamic> toJson() => {
        'is_premium': isPremium,
        'welcome_seen': welcomeSeen,
      };

  factory UserFlags.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserFlags();
    return UserFlags(
      isPremium: json['is_premium'] == true,
      welcomeSeen: json['welcome_seen'] == true,
    );
  }
}

class UserProfile {
  final String displayName;
  final String diet; // vegetarian|vegan|omnivore|none
  final List<String> allergies;
  final List<String> goals;
  final List<String> favoriteMarkets;

  const UserProfile({
    this.displayName = '',
    this.diet = 'none',
    this.allergies = const [],
    this.goals = const [],
    this.favoriteMarkets = const [],
  });

  UserProfile copyWith({
    String? displayName,
    String? diet,
    List<String>? allergies,
    List<String>? goals,
    List<String>? favoriteMarkets,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      diet: diet ?? this.diet,
      allergies: allergies ?? this.allergies,
      goals: goals ?? this.goals,
      favoriteMarkets: favoriteMarkets ?? this.favoriteMarkets,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'diet': diet,
        'allergies': allergies,
        'goals': goals,
        'favorite_markets': favoriteMarkets,
      };

  factory UserProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserProfile();
    return UserProfile(
      displayName: json['display_name']?.toString() ?? '',
      diet: json['diet']?.toString() ?? 'none',
      allergies: (json['allergies'] is List) ? (json['allergies'] as List).map((e) => e.toString()).toList() : const [],
      goals: (json['goals'] is List) ? (json['goals'] as List).map((e) => e.toString()).toList() : const [],
      favoriteMarkets: (json['favorite_markets'] is List)
          ? (json['favorite_markets'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class UserAccount {
  final String uid;
  final String email;
  final String? passwordHash; // legacy only (not exported)
  final String createdAt;
  final UserProfile profile;
  final UserFlags flags;

  const UserAccount({
    required this.uid,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    required this.profile,
    required this.flags,
  });

  UserAccount copyWith({
    String? email,
    String? passwordHash,
    String? createdAt,
    UserProfile? profile,
    UserFlags? flags,
  }) {
    return UserAccount(
      uid: uid,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      profile: profile ?? this.profile,
      flags: flags ?? this.flags,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        // IMPORTANT (privacy-by-design): credentials must NOT be exported to disk.
        // password_hash may exist in legacy files and is used for one-time migration only.
        'created_at': createdAt,
        'profile': profile.toJson(),
        'flags': flags.toJson(),
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      passwordHash: json['password_hash']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      profile: UserProfile.fromJson(json['profile'] is Map ? (json['profile'] as Map).cast<String, dynamic>() : null),
      flags: UserFlags.fromJson(json['flags'] is Map ? (json['flags'] as Map).cast<String, dynamic>() : null),
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}


