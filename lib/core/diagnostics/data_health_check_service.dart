import 'package:flutter/foundation.dart';

import '../storage/customer_storage.dart';

class DataHealthCheckResult {
  final bool writable;
  final String? rootPath;
  final int eventsLines;
  final bool profileOk;
  final bool prefsOk;
  final bool statsOk;
  final List<String> warnings;

  const DataHealthCheckResult({
    required this.writable,
    required this.rootPath,
    required this.eventsLines,
    required this.profileOk,
    required this.prefsOk,
    required this.statsOk,
    required this.warnings,
  });
}

class DataHealthCheckService {
  DataHealthCheckService._();
  static final DataHealthCheckService instance = DataHealthCheckService._();

  Future<DataHealthCheckResult> run() async {
    final storage = CustomerStorage.instance;
    final warnings = <String>[];

    bool writable = false;
    try {
      await storage.writeText('healthcheck_write_test.txt', 'ok');
      await storage.delete('healthcheck_write_test.txt');
      writable = true;
    } catch (e) {
      warnings.add('Not writable: $e');
    }

    int eventsLines = 0;
    try {
      final raw = await storage.readText('events_log.jsonl') ?? '';
      if (raw.isNotEmpty) {
        eventsLines = raw.split('\n').where((l) => l.trim().isNotEmpty).length;
      }
    } catch (e) {
      warnings.add('Event log unreadable: $e');
    }

    bool profileOk = false;
    bool prefsOk = false;
    bool statsOk = false;
    try {
      profileOk = (await storage.readJson('customer_profile.json')) != null;
    } catch (_) {}
    try {
      prefsOk = (await storage.readJson('customer_preferences.json')) != null;
    } catch (_) {}
    try {
      statsOk = (await storage.readJson('customer_app_stats.json')) != null;
    } catch (_) {}

    return DataHealthCheckResult(
      writable: writable,
      rootPath: storage.rootDebugPath,
      eventsLines: eventsLines,
      profileOk: profileOk,
      prefsOk: prefsOk,
      statsOk: statsOk,
      warnings: warnings,
    );
  }

  void printResult(DataHealthCheckResult r) {
    if (!kDebugMode) return;
    if (r.writable) {
      debugPrint('✅ dates_from_costumors writable: ${r.rootPath ?? "web virtual"}');
    } else {
      debugPrint('❌ dates_from_costumors NOT writable');
      debugPrint('   Fix: check path_provider / storage permissions');
    }

    debugPrint('✅ customer_profile.json: ${r.profileOk ? "ok" : "missing"}');
    debugPrint('✅ customer_preferences.json: ${r.prefsOk ? "ok" : "missing"}');
    debugPrint('✅ customer_app_stats.json: ${r.statsOk ? "ok" : "missing"}');
    debugPrint('✅ events_log.jsonl lines: ${r.eventsLines}');
    for (final w in r.warnings) {
      debugPrint('⚠️  $w');
    }
  }
}


