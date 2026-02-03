import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/grocify_theme.dart';
import '../data/journal_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> with SingleTickerProviderStateMixin {
  final _svc = JournalService.instance;
  late final TabController _tabs;

  bool _loading = true;
  List<String> _prompts = const [];
  final Map<String, TextEditingController> _controllers = {};
  List<JournalEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  String _prettyDate(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    return '$d. ${months[(m - 1).clamp(0, 11)]} $y';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prompts = _svc.promptsForToday();

    // controllers
    for (final q in prompts) {
      _controllers.putIfAbsent(q, () => TextEditingController());
    }

    final today = _todayKey();
    final existing = await _svc.loadForDate(today);
    if (existing != null) {
      for (final qa in existing.items) {
        final c = _controllers[qa.question];
        if (c != null) c.text = qa.answer;
      }
    }

    final history = await _svc.loadAll();
    if (!mounted) return;
    setState(() {
      _prompts = prompts;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final map = <String, String>{};
    for (final q in _prompts) {
      map[q] = _controllers[q]?.text ?? '';
    }
    await _svc.upsertToday(map);
    HapticFeedback.mediumImpact();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal gespeichert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: const Text('Journal', style: TextStyle(color: GrocifyTheme.textPrimary, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: GrocifyTheme.textPrimary),
        bottom: TabBar(
          controller: _tabs,
          labelColor: GrocifyTheme.textPrimary,
          unselectedLabelColor: GrocifyTheme.textSecondary,
          indicatorColor: GrocifyTheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Heute'),
            Tab(text: 'Verlauf'),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [
                  _TodayTab(
                    dateLabel: _prettyDate(_todayKey()),
                    prompts: _prompts,
                    controllers: _controllers,
                    onSave: _save,
                  ),
                  _HistoryTab(
                    entries: _history.where((e) => e.items.isNotEmpty).toList(),
                    prettyDate: _prettyDate,
                  ),
                ],
              ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  final String dateLabel;
  final List<String> prompts;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onSave;

  const _TodayTab({
    required this.dateLabel,
    required this.prompts,
    required this.controllers,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: GrocifyTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: GrocifyTheme.shadowMD,
          ),
          child: Row(
            children: [
              const Text('📓', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '5 Fragen – rotieren täglich',
                      style: TextStyle(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final q in prompts) ...[
          _QuestionCard(question: q, controller: controllers[q]!),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: GrocifyTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String question;
  final TextEditingController controller;

  const _QuestionCard({required this.question, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GrocifyTheme.border.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: GrocifyTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: null,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Deine Antwort…',
              filled: true,
              fillColor: GrocifyTheme.surfaceSubtle,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<JournalEntry> entries;
  final String Function(String ymd) prettyDate;

  const _HistoryTab({required this.entries, required this.prettyDate});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Noch keine Journal‑Einträge', style: TextStyle(color: GrocifyTheme.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in entries) ...[
          Text(
            prettyDate(e.date),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GrocifyTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          for (final qa in e.items) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GrocifyTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GrocifyTheme.border.withOpacity(0.55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(qa.question, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(qa.answer, style: const TextStyle(color: GrocifyTheme.textSecondary, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}


