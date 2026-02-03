/// Legal Detail Screen - Displays legal content in a scrollable view
import 'package:flutter/material.dart';
import '../../../core/theme/grocify_theme.dart';
import 'legal_content.dart';

class LegalDetailScreen extends StatelessWidget {
  final LegalContentType type;

  const LegalDetailScreen({
    super.key,
    required this.type,
  });

  String get _title {
    switch (type) {
      case LegalContentType.privacy:
        return 'Datenschutzerklärung';
      case LegalContentType.terms:
        return 'Nutzungsbedingungen';
      case LegalContentType.imprint:
        return 'Impressum';
      case LegalContentType.disclaimers:
        return 'Wichtige Hinweise';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = LegalContent.getContent(type);
    
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: Text(
          _title,
          style: const TextStyle(
            color: GrocifyTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: GrocifyTheme.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
          child: _buildContent(content),
        ),
      ),
    );
  }

  Widget _buildContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: GrocifyTheme.spaceMD));
        continue;
      }

      if (line.startsWith('# ')) {
        // H1 heading
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: GrocifyTheme.spaceLG, bottom: GrocifyTheme.spaceMD),
            child: Text(
              line.substring(2),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: GrocifyTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // H2 heading
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: GrocifyTheme.spaceXL, bottom: GrocifyTheme.spaceSM),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        // H3 heading
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: GrocifyTheme.spaceLG, bottom: GrocifyTheme.spaceXS),
            child: Text(
              line.substring(4),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        );
      } else if (line.startsWith('**') && line.endsWith('**')) {
        // Bold text
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: GrocifyTheme.spaceSM),
            child: Text(
              line.replaceAll('**', ''),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        );
      } else {
        // Regular paragraph
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: GrocifyTheme.spaceSM),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: GrocifyTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

