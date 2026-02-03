import 'customer_storage_impl.dart';

/// CustomerStorage
/// - Mobile/Desktop: real file system under documents dir
/// - Web: SharedPreferences-backed virtual file system (keys)
abstract class CustomerStorage {
  static final CustomerStorage _instance = CustomerStorageImpl();
  static CustomerStorage get instance => _instance;

  /// Initializes `dates_from_costumors/` and subfolders.
  Future<void> init();

  /// Debug path (mobile/desktop), null on web.
  String? get rootDebugPath;

  /// Returns decoded JSON map or null if missing.
  Future<Map<String, dynamic>?> readJson(String relativePath);

  Future<void> writeJson(String relativePath, Map<String, dynamic> data);

  /// Returns raw text or null if missing.
  Future<String?> readText(String relativePath);

  Future<void> writeText(String relativePath, String text);

  /// Appends raw text (no newline added automatically).
  Future<void> appendText(String relativePath, String text);

  Future<bool> exists(String relativePath);

  Future<void> delete(String relativePath);

  /// Lists direct children (files) under a folder, returning relative paths.
  Future<List<String>> list(String folderRelativePath);
}

class CustomerPaths {
  static const String root = 'dates_from_costumors';
  static const String users = 'users';
  static const String sessions = 'sessions';
  static const String streaks = 'streaks';
  static const String premium = 'premium';
  static const String logs = 'logs';

  static String userFile(String uid) => '$users/$uid.json';
  static String streakFile(String uid) => '$streaks/$uid.json';
  static String premiumFile(String uid) => '$premium/$uid.json';
  static String currentSessionFile() => '$sessions/current_user.json';
  static String appLogFile() => '$logs/app.log';
}


