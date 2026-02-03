class CustomerAppStats {
  final int streakDays;
  final String lastOpenDate; // YYYY-MM-DD
  final int opensCount;
  final bool premiumStatus;
  final String lastSeenVersion;
  final bool firstRunCompleted;
  final String lastPopupShownDate; // YYYY-MM-DD (prevents popup spam)

  const CustomerAppStats({
    required this.streakDays,
    required this.lastOpenDate,
    required this.opensCount,
    required this.premiumStatus,
    required this.lastSeenVersion,
    required this.firstRunCompleted,
    required this.lastPopupShownDate,
  });

  factory CustomerAppStats.defaults() => const CustomerAppStats(
        streakDays: 0,
        lastOpenDate: '',
        opensCount: 0,
        premiumStatus: false,
        lastSeenVersion: '',
        firstRunCompleted: true,
        lastPopupShownDate: '',
      );

  Map<String, dynamic> toJson() => {
        'streakDays': streakDays,
        'lastOpenDate': lastOpenDate,
        'opensCount': opensCount,
        'premiumStatus': premiumStatus,
        'lastSeenVersion': lastSeenVersion,
        'firstRunCompleted': firstRunCompleted,
        'lastPopupShownDate': lastPopupShownDate,
      };

  factory CustomerAppStats.fromJson(Map<String, dynamic> json) {
    return CustomerAppStats(
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      lastOpenDate: json['lastOpenDate']?.toString() ?? '',
      opensCount: (json['opensCount'] as num?)?.toInt() ?? 0,
      premiumStatus: json['premiumStatus'] == true,
      lastSeenVersion: json['lastSeenVersion']?.toString() ?? '',
      firstRunCompleted: json['firstRunCompleted'] as bool? ?? true,
      lastPopupShownDate: json['lastPopupShownDate']?.toString() ?? '',
    );
  }
}


