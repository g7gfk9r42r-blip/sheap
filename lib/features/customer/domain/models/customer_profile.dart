class CustomerProfile {
  final String userId;
  final String email;
  final String? name;
  final String createdAt; // ISO-8601 UTC
  final String lastLoginAt; // ISO-8601 UTC
  final String consentAcceptedAt; // ISO-8601 UTC

  const CustomerProfile({
    required this.userId,
    required this.email,
    required this.name,
    required this.createdAt,
    required this.lastLoginAt,
    required this.consentAcceptedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'name': name,
        'createdAt': createdAt,
        'lastLoginAt': lastLoginAt,
        'consentAcceptedAt': consentAcceptedAt,
      };

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      userId: (json['userId']?.toString() ?? json['id']?.toString() ?? '').trim(),
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      lastLoginAt: json['lastLoginAt']?.toString() ?? '',
      consentAcceptedAt: json['consentAcceptedAt']?.toString() ?? '',
    );
  }
}


