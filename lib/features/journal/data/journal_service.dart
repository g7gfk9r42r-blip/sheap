import 'package:flutter/foundation.dart';

import '../../../core/storage/customer_storage.dart';
import '../../customer/data/customer_data_store.dart';

class JournalQA {
  final String question;
  final String answer;

  const JournalQA({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {'q': question, 'a': answer};

  factory JournalQA.fromJson(Map<String, dynamic> json) {
    return JournalQA(
      question: json['q']?.toString() ?? '',
      answer: json['a']?.toString() ?? '',
    );
  }
}

class JournalEntry {
  final String date; // YYYY-MM-DD
  final List<JournalQA> items;
  final String createdAt; // ISO
  final String updatedAt; // ISO

  const JournalEntry({
    required this.date,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'items': items.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      date: json['date']?.toString() ?? '',
      items: (json['items'] is List)
          ? (json['items'] as List)
              .map((e) => e is Map ? JournalQA.fromJson(Map<String, dynamic>.from(e)) : null)
              .whereType<JournalQA>()
              .toList()
          : const [],
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class JournalService {
  JournalService._();
  static final JournalService instance = JournalService._();

  static const _filePath = 'journal/journal_entries.json';

  static const List<String> questions = [
    'Was war heute das Beste, was passiert ist (auch wenn es klein war)?',
    'Welche Sache hat dir heute Energie gegeben – und warum?',
    'Welche Sache hat dir heute Energie genommen – und was könntest du morgen anders machen?',
    'Worauf bist du heute stolz?',
    'Was hast du heute gelernt (über dich oder über etwas anderes)?',
    'Welche Entscheidung war heute richtig – obwohl sie vielleicht schwer war?',
    'Wofür bist du heute dankbar (3 Dinge)?',
    'Welcher Moment hat dich heute zum Lächeln gebracht?',
    'Was willst du morgen unbedingt vermeiden – und wie machst du es konkret?',
    'Was wäre morgen ein kleiner, realistischer Erfolg?',
    'Welche Gewohnheit hat dir heute gutgetan?',
    'Was hat heute deinen Fokus gestört – und welche 1 Grenze setzt du morgen?',
    'Wie geht es dir gerade wirklich (1 Satz ohne Schönreden)?',
    'Welche Person hat heute einen positiven Einfluss gehabt – und warum?',
    'Was würdest du deinem “Morgen-Ich” kurz mitgeben?',
    'Welche Aufgabe schiebst du auf – und was ist der kleinste nächste Schritt?',
    'Was willst du diese Woche mehr machen – und was weniger?',
    'Welche Mahlzeit hat dir heute gutgetan – und warum (Sättigung/Genuss/Protein)?',
    'Welche Zutat/Meal-Prep Idee möchtest du nächste Woche testen?',
    'Wenn heute ein Kapitel war: Wie würde es heißen?',
  ];

  String _todayKey(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  int _daysSinceEpoch(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return d.difference(DateTime(1970, 1, 1)).inDays;
  }

  List<String> promptsForToday() {
    final dayIndex = _daysSinceEpoch(DateTime.now());
    final start = dayIndex % questions.length; // 20-day rotation
    return List.generate(5, (i) => questions[(start + i) % questions.length]);
  }

  Future<List<JournalEntry>> loadAll() async {
    final json = await CustomerStorage.instance.readJson(_filePath);
    if (json == null) return const [];
    final list = json['entries'];
    if (list is! List) return const [];
    return list
        .map((e) => e is Map ? JournalEntry.fromJson(Map<String, dynamic>.from(e)) : null)
        .whereType<JournalEntry>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<JournalEntry?> loadForDate(String date) async {
    final all = await loadAll();
    try {
      return all.firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertToday(Map<String, String> answersByQuestion) async {
    final now = DateTime.now();
    final today = _todayKey(now);
    final nowIso = now.toUtc().toIso8601String();

    final prompts = promptsForToday();
    final items = prompts
        .map((q) => JournalQA(question: q, answer: (answersByQuestion[q] ?? '').trim()))
        .where((qa) => qa.answer.isNotEmpty)
        .toList();

    final existing = await loadAll();
    final idx = existing.indexWhere((e) => e.date == today);
    final entry = JournalEntry(
      date: today,
      items: items,
      createdAt: idx >= 0 ? existing[idx].createdAt : nowIso,
      updatedAt: nowIso,
    );

    final next = [...existing];
    if (idx >= 0) {
      next[idx] = entry;
    } else {
      next.add(entry);
    }

    await CustomerStorage.instance.writeJson(_filePath, {
      'entries': next.map((e) => e.toJson()).toList(),
    });

    await CustomerDataStore.instance.logEvent('journal_save', {
      'date': today,
      'answeredCount': items.length,
    });

    if (kDebugMode) debugPrint('📓 Journal saved: $today answered=${items.length}');
  }

  Future<int> countDaysWithEntries() async {
    final all = await loadAll();
    return all.where((e) => e.items.isNotEmpty).length;
  }
}


