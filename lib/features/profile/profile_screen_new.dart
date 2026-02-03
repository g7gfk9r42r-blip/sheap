/// Premium Profile Screen
/// Statistics, achievements, settings, legal information, premium status
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/grocify_theme.dart';
import '../../core/utils/links.dart';
import '../settings/settings_screen.dart' show SettingsScreen;
import '../premium/premium_service.dart';
import '../premium/widgets/upgrade_bar.dart';
import '../journal/presentation/journal_screen.dart';
import '../journal/data/journal_service.dart';
import '../customer/presentation/my_data_screen.dart';
import '../legal/presentation/legal_markdown_screen.dart';
import '../customer/data/customer_data_store.dart';

class ProfileScreenNew extends StatefulWidget {
  const ProfileScreenNew({super.key});

  @override
  State<ProfileScreenNew> createState() => _ProfileScreenNewState();
}

class _ProfileScreenNewState extends State<ProfileScreenNew> {
  final _premiumService = PremiumService.instance;
  PackageInfo? _packageInfo;
  int _journalDays = 0;
  bool _myDataUnlocked = false;
  int _versionTapCount = 0;
  String? _displayName;
  int _streakDays = 0;
  String? _weeksLabel;
  static const String _supportEmail = 'romw24@icloud.com';

  @override
  void initState() {
    super.initState();
    _premiumService.addListener(_onPremiumChanged);
    _loadPackageInfo();
    _loadJournalCount();
    _loadMyDataUnlock();
    _loadCustomerBits();
  }

  @override
  void dispose() {
    _premiumService.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = info;
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _loadJournalCount() async {
    try {
      final days = await JournalService.instance.countDaysWithEntries();
      if (mounted) setState(() => _journalDays = days);
    } catch (_) {}
  }

  Future<void> _loadCustomerBits() async {
    try {
      final profile = await CustomerDataStore.instance.loadProfile();
      final stats = await CustomerDataStore.instance.loadAppStats();
      if (!mounted) return;
      setState(() {
        _displayName = profile?.name?.trim();
        _streakDays = stats.streakDays;
        _weeksLabel = _computeWeeksLabel(profile?.createdAt);
      });
    } catch (_) {}
  }

  String? _computeWeeksLabel(String? createdAtIso) {
    if (createdAtIso == null) return null;
    final raw = createdAtIso.trim();
    if (raw.isEmpty) return null;
    final createdAt = DateTime.tryParse(raw);
    if (createdAt == null) return null;
    final now = DateTime.now().toUtc();
    final days = now.difference(createdAt.toUtc()).inDays;
    final weeks = (days / 7).ceil().clamp(1, 9999);
    return weeks == 1 ? '1 Woche dabei' : '$weeks Wochen dabei';
  }

  Future<void> _loadMyDataUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getBool('dev_my_data_unlocked') ?? false;
    if (mounted) setState(() => _myDataUnlocked = unlocked);
  }

  Future<void> _handleVersionTap() async {
    _versionTapCount += 1;
    if (_myDataUnlocked) return;
    if (_versionTapCount < 7) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_my_data_unlocked', true);
    if (!mounted) return;
    setState(() => _myDataUnlocked = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Developer‑Zugriff aktiviert: „Meine Daten“ ist jetzt sichtbar.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MVP: keep recipes cooked as placeholder metric (can be wired later)
    final recipesCooked = 12;

    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(
            color: GrocifyTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: GrocifyTheme.textPrimary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserCard(),
            const SizedBox(height: GrocifyTheme.spaceXXL),

            if (!_premiumService.premiumActive)
              const UpgradeBar(customMessage: 'Erweiterte Features freischalten'),
            if (_premiumService.premiumActive) _buildPremiumBadge(),
            const SizedBox(height: GrocifyTheme.spaceXXL),

            _buildStreakCard(_streakDays),
            const SizedBox(height: GrocifyTheme.spaceXXL),

            _buildStatisticsSection(recipesCooked),
            const SizedBox(height: GrocifyTheme.spaceXXL),

            _buildInformationSection(),
            const SizedBox(height: GrocifyTheme.spaceLG),

            _buildLegalSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    final name = (_displayName ?? '').trim().isEmpty ? 'Roman Wolf' : _displayName!.trim();
    return Container(
      decoration: BoxDecoration(
        gradient: GrocifyTheme.primaryGradient,
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusXXL),
        boxShadow: GrocifyTheme.shadowMD,
      ),
      child: Padding(
        padding: const EdgeInsets.all(GrocifyTheme.spaceXXL),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: GrocifyTheme.spaceLG),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: GrocifyTheme.spaceXS),
                  Text(
                    (() {
                      final s = (_weeksLabel ?? '').trim();
                      return s.isEmpty ? 'Neu dabei' : s;
                    })(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (_premiumService.premiumActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: GrocifyTheme.spaceMD,
                  vertical: GrocifyTheme.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBadge() {
    // Requested: grey out premium field even if active (Coming soon)
    final base = Container(
      padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
        border: Border.all(color: GrocifyTheme.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: GrocifyTheme.textSecondary, size: 24),
          const SizedBox(width: GrocifyTheme.spaceMD),
          const Expanded(
            child: Text(
              'Premium (Coming soon)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: GrocifyTheme.textSecondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.18),
              foregroundColor: GrocifyTheme.textSecondary,
            ),
            child: const Text('Coming soon', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        base,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
            child: Container(color: Colors.grey.withOpacity(0.10)),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(int streakDays) {
    return Container(
              padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
              decoration: BoxDecoration(
                color: GrocifyTheme.surface,
                borderRadius: BorderRadius.circular(GrocifyTheme.radiusXL),
                boxShadow: GrocifyTheme.shadowSM,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
                    decoration: BoxDecoration(
                      color: GrocifyTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: GrocifyTheme.accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: GrocifyTheme.spaceLG),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Streak',
                          style: TextStyle(
                            fontSize: 14,
                            color: GrocifyTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '$streakDays Tage',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: GrocifyTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '🔥',
                    style: TextStyle(fontSize: 32),
                  ),
                ],
              ),
    );
  }

  Widget _buildStatisticsSection(int recipesCooked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            const Text(
              'Statistiken',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceLG),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Rezepte',
                    value: '$recipesCooked',
                    color: GrocifyTheme.primary,
                  ),
                ),
                const SizedBox(width: GrocifyTheme.spaceLG),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.book_rounded,
                    label: 'Journal',
                    value: '$_journalDays',
                    color: GrocifyTheme.accent,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalScreen()));
                    },
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
      child: Container(
        padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
        decoration: BoxDecoration(
          color: GrocifyTheme.surface,
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
          boxShadow: GrocifyTheme.shadowSM,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: GrocifyTheme.spaceSM),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: GrocifyTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationSection() {
    return _buildSection(
      title: 'Informationen',
      icon: Icons.info_outline_rounded,
      children: [
        _buildSectionItem(
          icon: Icons.info_outline_rounded,
          title: 'Über Grocify',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Über Grocify'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grocify ist deine intelligente App für Meal Planning und Einkaufslisten. '
                      'Plane deine Woche, entdecke neue Rezepte und spare Zeit beim Einkaufen.\n',
                    ),
                    if (_packageInfo != null) ...[
                      const SizedBox(height: GrocifyTheme.spaceMD),
                      InkWell(
                        onTap: _handleVersionTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Version ${_packageInfo!.version} (${_packageInfo!.buildNumber})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: GrocifyTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
        _buildSectionItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Datenschutzerklärung',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalMarkdownScreen(
                  title: 'Datenschutzerklärung',
                  assetPath: 'assets/legal/datenschutz.md',
                ),
              ),
            );
          },
        ),
        _buildSectionItem(
          icon: Icons.description_outlined,
          title: 'AGB',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalMarkdownScreen(
                  title: 'AGB',
                  assetPath: 'assets/legal/agb.md',
                ),
              ),
            );
          },
        ),
        if (_myDataUnlocked)
          _buildSectionItem(
            icon: Icons.folder_open_rounded,
            title: 'Meine Daten (Export)',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyDataScreen()));
            },
          ),
        _buildSectionItem(
          icon: Icons.email_outlined,
          title: 'Kontakt',
          onTap: () {
            AppLinks.openMailto(
              _supportEmail,
              subject: 'Anfrage zu Grocify',
            );
          },
        ),
        _buildSectionItem(
          icon: Icons.feedback_outlined,
          title: 'Feedback',
          onTap: () {
            AppLinks.openMailto(
              _supportEmail,
              subject: 'Feedback zu Grocify',
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegalSection() {
    return _buildSection(
      title: 'Rechtliches',
      icon: Icons.gavel_rounded,
      children: [
        _buildSectionItem(
          icon: Icons.business_outlined,
          title: 'Impressum',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalMarkdownScreen(
                  title: 'Impressum',
                  assetPath: 'assets/legal/impressum.md',
                ),
              ),
            );
          },
        ),
        _buildSectionItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Datenschutzerklärung',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalMarkdownScreen(
                  title: 'Datenschutzerklärung',
                  assetPath: 'assets/legal/datenschutz.md',
                ),
              ),
            );
          },
        ),
        _buildSectionItem(
          icon: Icons.description_outlined,
          title: 'AGB',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalMarkdownScreen(
                  title: 'AGB',
                  assetPath: 'assets/legal/agb.md',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: GrocifyTheme.textSecondary, size: 20),
            const SizedBox(width: GrocifyTheme.spaceSM),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: GrocifyTheme.spaceMD),
        Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
            boxShadow: GrocifyTheme.shadowSM,
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: GrocifyTheme.spaceLG,
            vertical: GrocifyTheme.spaceSM,
      ),
          leading: Icon(icon, color: GrocifyTheme.textSecondary, size: 24),
        title: Text(
          title,
          style: const TextStyle(
              fontSize: 16,
            fontWeight: FontWeight.w500,
            color: GrocifyTheme.textPrimary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
            color: GrocifyTheme.textSecondary,
            size: 20,
        ),
        onTap: onTap,
        ),
        if (title != _getLastItemTitle()) // Add divider except for last item
          Divider(
            height: 1,
            thickness: 1,
            color: GrocifyTheme.divider,
            indent: GrocifyTheme.spaceLG + 24 + GrocifyTheme.spaceMD,
        ),
      ],
    );
  }

  String _getLastItemTitle() {
    // Return last item title for divider logic
    return 'AGB';
  }
}

// (removed) Quick actions row — reverted to the previous simpler profile layout.
