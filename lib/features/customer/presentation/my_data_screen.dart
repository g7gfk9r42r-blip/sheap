import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/grocify_theme.dart';
import '../data/customer_data_store.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  bool _loading = true;
  List<({String name, String? content})> _files = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await CustomerDataStore.instance.loadAllFilesForDebug();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _exportAll() async {
    await CustomerDataStore.instance.logEvent('export_data_clicked', {});
    final text = _files
        .map((f) => '=== ${f.name} ===\n${f.content ?? "(missing)"}\n')
        .join('\n');
    await Share.share(text, subject: 'sheap – Meine Daten Export');
  }

  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alles löschen?'),
        content: const Text('Alle lokalen Kundendaten (JSON + Event Log) werden gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: GrocifyTheme.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CustomerDataStore.instance.logEvent('delete_data_clicked', {});
    await CustomerDataStore.instance.deleteAllCustomerFiles();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: const Text('Meine Daten', style: TextStyle(color: GrocifyTheme.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GrocifyTheme.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Exportieren',
            onPressed: _loading ? null : _exportAll,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GrocifyTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GrocifyTheme.border.withOpacity(0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open_rounded, color: GrocifyTheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'dates_from_costumors/\n(alle Dateien sind lokal exportierbar)',
                            style: TextStyle(color: GrocifyTheme.textSecondary.withOpacity(0.95), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final f in _files) ...[
                    _FileCard(
                      name: f.name,
                      content: f.content,
                      onShare: () async => Share.share(f.content ?? '', subject: f.name),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirmDeleteAll,
                      style: FilledButton.styleFrom(backgroundColor: GrocifyTheme.error),
                      child: const Text('Alles löschen', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final String name;
  final String? content;
  final VoidCallback onShare;

  const _FileCard({
    required this.name,
    required this.content,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final text = content ?? '';
    final preview = text.isEmpty ? '(missing)' : (text.length > 900 ? '${text.substring(0, 900)}\n…' : text);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrocifyTheme.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GrocifyTheme.textPrimary),
                ),
              ),
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GrocifyTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GrocifyTheme.border.withOpacity(0.4)),
            ),
            child: Text(
              preview,
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 12, height: 1.25, color: GrocifyTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}


