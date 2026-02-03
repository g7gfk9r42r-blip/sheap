import 'dart:convert';
import '../customer_storage.dart';

/// Shared helpers and default normalizations (no dart:io, no dart:html).
abstract class CustomerStorageCommon implements CustomerStorage {
  String encodeJson(Map<String, dynamic> data) => const JsonEncoder.withIndent('  ').convert(data);

  Map<String, dynamic> decodeJson(String raw) => json.decode(raw) as Map<String, dynamic>;

  String normalize(String relativePath) {
    var p = relativePath.trim();
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  String normalizeFolder(String folderRelativePath) {
    var p = normalize(folderRelativePath);
    if (p.isEmpty) return p;
    if (!p.endsWith('/')) p = '$p/';
    return p;
  }
}


