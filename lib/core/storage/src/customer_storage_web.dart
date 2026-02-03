import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../customer_storage.dart';
import 'customer_storage_common.dart';

class CustomerStorageImpl extends CustomerStorageCommon {
  SharedPreferences? _prefs;

  String _key(String relativePath) => '${CustomerPaths.root}/${normalize(relativePath)}';

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (kDebugMode) {
      debugPrint('✅ CustomerStorage(WEB) init: virtual folder "${CustomerPaths.root}/"');
    }
  }

  @override
  String? get rootDebugPath => null;

  @override
  Future<Map<String, dynamic>?> readJson(String relativePath) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(relativePath));
    if (raw == null || raw.isEmpty) return null;
    try {
      return decodeJson(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ CustomerStorage(WEB) readJson failed: $relativePath -> $e');
      return null;
    }
  }

  @override
  Future<void> writeJson(String relativePath, Map<String, dynamic> data) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_key(relativePath), encodeJson(data));
  }

  @override
  Future<String?> readText(String relativePath) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(_key(relativePath));
  }

  @override
  Future<void> writeText(String relativePath, String text) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_key(relativePath), text);
  }

  @override
  Future<void> appendText(String relativePath, String text) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final k = _key(relativePath);
    final prev = prefs.getString(k) ?? '';
    await prefs.setString(k, '$prev$text');
  }

  @override
  Future<bool> exists(String relativePath) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.containsKey(_key(relativePath));
  }

  @override
  Future<void> delete(String relativePath) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_key(relativePath));
  }

  @override
  Future<List<String>> list(String folderRelativePath) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final folder = normalizeFolder(folderRelativePath);
    final prefix = '${CustomerPaths.root}/$folder';
    final out = <String>[];
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final rel = k.substring(CustomerPaths.root.length + 1); // strip "dates_from_costumors/"
      out.add(rel);
    }
    out.sort();
    return out;
  }
}


