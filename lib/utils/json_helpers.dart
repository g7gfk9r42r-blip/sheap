/// Robust JSON parsing helpers to prevent type cast crashes
class JsonHelpers {
  /// Safely cast to String, returns null if not a string
  static String? asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely cast to int, returns null if not a number
  static int? asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }

  /// Safely cast to double, returns null if not a number
  static double? asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  /// Safely cast to List, returns null if not a list
  static List<T>? asList<T>(dynamic value, T Function(dynamic) mapper) {
    if (value == null) return null;
    if (value is! List) return null;
    
    try {
      return value.map((e) => mapper(e)).whereType<T>().toList();
    } catch (e) {
      return null;
    }
  }

  /// Safely cast to List<String>, handles mixed types
  static List<String>? asStringList(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;
    
    try {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return null;
    }
  }

  /// Safely cast to Map, returns null if not a map
  static Map<String, dynamic>? asMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
