/// Legal Hub Screen - Central hub for all legal documents
import 'package:flutter/material.dart';
import '../../../core/theme/grocify_theme.dart';
import 'legal_detail_screen.dart';
import 'legal_content.dart';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: const Text(
          'Rechtliches',
          style: TextStyle(
            color: GrocifyTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: GrocifyTheme.textPrimary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
          children: [
            _buildLegalItem(
              context: context,
              icon: Icons.lock_outline_rounded,
              title: 'Datenschutzerklärung',
              subtitle: 'Informationen zur Datenverarbeitung',
              type: LegalContentType.privacy,
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            _buildLegalItem(
              context: context,
              icon: Icons.description_outlined,
              title: 'Nutzungsbedingungen',
              subtitle: 'AGB und Nutzungsbestimmungen',
              type: LegalContentType.terms,
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            _buildLegalItem(
              context: context,
              icon: Icons.business_outlined,
              title: 'Impressum / Anbieter',
              subtitle: 'Kontakt und rechtliche Angaben',
              type: LegalContentType.imprint,
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            _buildLegalItem(
              context: context,
              icon: Icons.info_outline_rounded,
              title: 'Wichtige Hinweise',
              subtitle: 'Disclaimer zu Preisen und Marken',
              type: LegalContentType.disclaimers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required LegalContentType type,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
        side: BorderSide(color: GrocifyTheme.border, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GrocifyTheme.spaceLG,
          vertical: GrocifyTheme.spaceMD,
        ),
        leading: Container(
          padding: const EdgeInsets.all(GrocifyTheme.spaceMD),
          decoration: BoxDecoration(
            color: GrocifyTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
          ),
          child: Icon(icon, color: GrocifyTheme.primary, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: GrocifyTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: GrocifyTheme.spaceXS),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: GrocifyTheme.textSecondary,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: GrocifyTheme.textSecondary,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LegalDetailScreen(type: type),
            ),
          );
        },
      ),
    );
  }
}

