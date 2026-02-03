import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/customer_storage.dart';
import '../domain/models/customer_app_stats.dart';
import '../domain/models/customer_preferences.dart';
import '../domain/models/customer_profile.dart';

class CustomerDataStore {
  CustomerDataStore._();
  static final CustomerDataStore instance = CustomerDataStore._();

  static const String _profileFile = 'customer_profile.json';
  static const String _prefsFile = 'customer_preferences.json';
  static const String _statsFile = 'customer_app_stats.json';
  static const String _eventsFile = 'events_log.jsonl';

  static const String _kProfile = 'customer_profile_json';
  static const String _kPrefs = 'customer_preferences_json';
  static const String _kStats = 'customer_app_stats_json';

  final _storage = CustomerStorage.instance;

  Future<void> logEvent(String type, Map<String, dynamic> payload) async {
    final line = json.encode({
      'type': type,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...payload,
    });
    await _storage.appendText(_eventsFile, '$line\n');
  }

  Future<CustomerProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfile);
    if (raw != null && raw.isNotEmpty) {
      try {
        return CustomerProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final fileJson = await _storage.readJson(_profileFile);
    if (fileJson == null) return null;
    return CustomerProfile.fromJson(fileJson);
  }

  Future<CustomerPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefs);
    if (raw != null && raw.isNotEmpty) {
      try {
        return CustomerPreferences.fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final fileJson = await _storage.readJson(_prefsFile);
    if (fileJson == null) return CustomerPreferences.defaults();
    return CustomerPreferences.fromJson(fileJson);
  }

  Future<CustomerAppStats> loadAppStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStats);
    if (raw != null && raw.isNotEmpty) {
      try {
        return CustomerAppStats.fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final fileJson = await _storage.readJson(_statsFile);
    if (fileJson == null) return CustomerAppStats.defaults();
    return CustomerAppStats.fromJson(fileJson);
  }

  Future<void> saveProfile(CustomerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(profile.toJson());
    await prefs.setString(_kProfile, raw);
    await _storage.writeJson(_profileFile, profile.toJson());
  }

  Future<void> savePreferences(CustomerPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(preferences.toJson());
    await prefs.setString(_kPrefs, raw);
    await _storage.writeJson(_prefsFile, preferences.toJson());
  }

  Future<void> saveAppStats(CustomerAppStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(stats.toJson());
    await prefs.setString(_kStats, raw);
    await _storage.writeJson(_statsFile, stats.toJson());
  }

  Future<List<({String name, String? content})>> loadAllFilesForDebug() async {
    final files = <String>[
      _profileFile,
      _prefsFile,
      _statsFile,
      _eventsFile,
      'journal/journal_entries.json',
    ];
    final out = <({String name, String? content})>[];
    for (final f in files) {
      final text = await _storage.readText(f);
      out.add((name: f, content: text));
    }
    return out;
  }

  Future<void> deleteAllCustomerFiles() async {
    await _storage.delete(_profileFile);
    await _storage.delete(_prefsFile);
    await _storage.delete(_statsFile);
    await _storage.delete(_eventsFile);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfile);
    await prefs.remove(_kPrefs);
    await prefs.remove(_kStats);

    if (kDebugMode) debugPrint('🧹 CustomerDataStore: deleted all customer files');
  }
}


