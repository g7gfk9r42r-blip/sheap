import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../customer_storage.dart';
import 'customer_storage_common.dart';

class CustomerStorageImpl extends CustomerStorageCommon {
  Directory? _rootDir;

  @override
  String? get rootDebugPath => _rootDir?.path;

  String _absPath(String relativePath) {
    final root = _rootDir;
    if (root == null) throw StateError('CustomerStorage not initialized');
    final p = normalize(relativePath);
    return '${root.path}/$p';
  }

  Future<void> _ensureDir(String relativeFolder) async {
    final root = _rootDir;
    if (root == null) throw StateError('CustomerStorage not initialized');
    final folder = normalize(relativeFolder);
    final dir = Directory('${root.path}/$folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  @override
  Future<void> init() async {
    final docDir = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${docDir.path}/${CustomerPaths.root}');
    if (!await _rootDir!.exists()) {
      await _rootDir!.create(recursive: true);
    }

    await _ensureDir(CustomerPaths.users);
    await _ensureDir(CustomerPaths.sessions);
    await _ensureDir(CustomerPaths.streaks);
    await _ensureDir(CustomerPaths.premium);
    await _ensureDir(CustomerPaths.logs);

    if (kDebugMode) {
      debugPrint('✅ CustomerStorage(IO) init: ${_rootDir!.path}');
    }
  }

  @override
  Future<Map<String, dynamic>?> readJson(String relativePath) async {
    final abs = _absPath(relativePath);
    final file = File(abs);
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      return decodeJson(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ CustomerStorage(IO) readJson failed: $relativePath -> $e');
      return null;
    }
  }

  @override
  Future<void> writeJson(String relativePath, Map<String, dynamic> data) async {
    final abs = _absPath(relativePath);
    final file = File(abs);
    await file.parent.create(recursive: true);
    await file.writeAsString(encodeJson(data));
  }

  @override
  Future<String?> readText(String relativePath) async {
    final abs = _absPath(relativePath);
    final file = File(abs);
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ CustomerStorage(IO) readText failed: $relativePath -> $e');
      return null;
    }
  }

  @override
  Future<void> writeText(String relativePath, String text) async {
    final abs = _absPath(relativePath);
    final file = File(abs);
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  @override
  Future<void> appendText(String relativePath, String text) async {
    final abs = _absPath(relativePath);
    final file = File(abs);
    await file.parent.create(recursive: true);
    await file.writeAsString(text, mode: FileMode.append, flush: true);
  }

  @override
  Future<bool> exists(String relativePath) async {
    final abs = _absPath(relativePath);
    return File(abs).exists();
  }

  @override
  Future<void> delete(String relativePath) async {
    final abs = _absPath(relativePath);
    final f = File(abs);
    if (await f.exists()) {
      await f.delete();
    }
  }

  @override
  Future<List<String>> list(String folderRelativePath) async {
    final root = _rootDir;
    if (root == null) throw StateError('CustomerStorage not initialized');
    final folder = normalize(folderRelativePath);
    final dir = Directory('${root.path}/$folder');
    if (!await dir.exists()) return <String>[];
    final out = <String>[];
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is File) {
        final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : '';
        if (name.isEmpty) continue;
        out.add('${folder.replaceAll(RegExp(r'/$'), '')}/$name');
      }
    }
    return out;
  }
}


