import 'package:flutter/foundation.dart';

import 'customer_storage_common.dart';

/// Fallback for platforms we don't handle.
class CustomerStorageImpl extends CustomerStorageCommon {
  final Map<String, String> _files = <String, String>{};

  @override
  Future<void> init() async {
    if (kDebugMode) {
      debugPrint('⚠️ CustomerStorage(STUB) init: unsupported platform, no-op');
    }
  }

  @override
  String? get rootDebugPath => null;

  @override
  Future<Map<String, dynamic>?> readJson(String relativePath) async {
    final raw = await readText(relativePath);
    if (raw == null || raw.isEmpty) return null;
    try {
      return decodeJson(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeJson(String relativePath, Map<String, dynamic> data) async {
    await writeText(relativePath, encodeJson(data));
  }

  @override
  Future<String?> readText(String relativePath) async {
    final p = normalize(relativePath);
    return _files[p];
  }

  @override
  Future<void> writeText(String relativePath, String text) async {
    final p = normalize(relativePath);
    _files[p] = text;
  }

  @override
  Future<void> appendText(String relativePath, String text) async {
    final p = normalize(relativePath);
    final prev = _files[p] ?? '';
    _files[p] = '$prev$text';
  }

  @override
  Future<bool> exists(String relativePath) async {
    final p = normalize(relativePath);
    return _files.containsKey(p);
  }

  @override
  Future<void> delete(String relativePath) async {
    final p = normalize(relativePath);
    _files.remove(p);
  }

  @override
  Future<List<String>> list(String folderRelativePath) async {
    final folder = normalizeFolder(folderRelativePath);
    if (folder.isEmpty) return _files.keys.toList()..sort();

    final out = <String>[];
    for (final k in _files.keys) {
      if (!k.startsWith(folder)) continue;
      final rest = k.substring(folder.length);
      if (rest.isEmpty) continue;
      // direct children only
      if (rest.contains('/')) continue;
      out.add(k);
    }
    out.sort();
    return out;
  }
}


