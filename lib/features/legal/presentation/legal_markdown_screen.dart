import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/grocify_theme.dart';

class LegalMarkdownScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const LegalMarkdownScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LegalMarkdownScreen> createState() => _LegalMarkdownScreenState();
}

class _LegalMarkdownScreenState extends State<LegalMarkdownScreen> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      setState(() => _content = raw);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Konnte Datei nicht laden: ${widget.assetPath}\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: GrocifyTheme.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GrocifyTheme.textPrimary),
      ),
      body: SafeArea(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: GrocifyTheme.error)),
              )
            : (_content == null)
                ? const Center(child: CircularProgressIndicator())
                : Markdown(
                    data: _content!,
                    padding: const EdgeInsets.all(16),
                    selectable: true,
                  ),
      ),
    );
  }
}


