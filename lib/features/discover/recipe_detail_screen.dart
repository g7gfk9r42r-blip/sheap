/// Recipe Detail Screen
/// Zeigt Rezept-Details + Angebote für Zutaten
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/recipe.dart';
import '../../data/models/offer.dart';
import '../../data/repositories/offer_repository.dart';
import '../../utils/week.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  List<Offer?> _offers = [];
  bool _isLoadingOffers = true;
  double _totalSaving = 0.0;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoadingOffers = true;
    });

    try {
      final weekKey = isoWeekKey(DateTime.now());
      final offers = await OfferRepository.getOffers(
        retailer: widget.recipe.retailer,
        weekKey: weekKey,
      );

      // Match ingredients with offers
      final matchedOffers = <Offer?>[];
      for (final ingredient in widget.recipe.ingredients) {
        if (offers.isEmpty) {
          matchedOffers.add(null);
          continue;
        }
        try {
          final matchingOffer = offers.firstWhere(
            (offer) => offer.title.toLowerCase().contains(ingredient.toLowerCase()) ||
                ingredient.toLowerCase().contains(offer.title.toLowerCase()),
          );
          matchedOffers.add(matchingOffer);
        } catch (_) {
          // No matching offer found
          matchedOffers.add(null);
        }
      }

      // Calculate total saving
      final totalSaving = matchedOffers.fold<double>(
        0.0,
        (sum, offer) => sum + (offer?.price ?? 0.0) * 0.1, // Mock: 10% saving
      );

      setState(() {
        _offers = matchedOffers;
        _totalSaving = totalSaving;
        _isLoadingOffers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingOffers = false;
      });
    }
  }

  void _addToPlan() {
    // TODO: Add to weekly plan
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rezept zum Planer hinzugefügt! ✨')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Build ingredient list with offers
    final ingredientItems = widget.recipe.ingredients.asMap().entries.map((entry) {
      final index = entry.key;
      final ingredient = entry.value;
      final offer = index < _offers.length ? _offers[index] : null;

      return _IngredientViewModel(
        index: index,
        name: ingredient,
        offer: offer,
      );
    }).toList();

    final marketLabel = (widget.recipe.market?.trim().isNotEmpty == true)
        ? widget.recipe.market!.trim().toUpperCase()
        : widget.recipe.retailer.trim().toUpperCase();

    final hasSteps = (widget.recipe.steps != null && widget.recipe.steps!.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _HeroHeader(
                  recipe: widget.recipe,
                  marketLabel: marketLabel,
                  isLoadingOffers: _isLoadingOffers,
                  onBack: () => Navigator.of(context).maybePop(),
                  onShare: () {
                    final lines = <String>[
                      widget.recipe.title.trim(),
                      'Supermarkt: ${marketLabel.toUpperCase()}',
                      if (widget.recipe.durationMinutes != null && widget.recipe.durationMinutes! > 0)
                        'Dauer: ${widget.recipe.durationMinutes} min',
                      if (widget.recipe.servings != null && widget.recipe.servings! > 0)
                        'Portionen: ${widget.recipe.servings}',
                      '',
                      'Zutaten:',
                      ...widget.recipe.ingredients.map((s) => '- ${s.trim()}'),
                      '',
                      'Schritte:',
                      ...(widget.recipe.steps ?? const <String>[])
                          .take(12)
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value.trim()}'),
                    ];
                    final text = lines.where((s) => s.trim().isNotEmpty).join('\n');
                    Share.share(text, subject: widget.recipe.title.trim());
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 140), // bottom for sticky CTA
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _FadeSlideIn(
                      delayMs: 0,
                      child: _TitleBlock(
                        title: widget.recipe.title,
                        subtitle: marketLabel,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FadeSlideIn(
                      delayMs: 60,
                      child: _QuickFactsRow(
                        durationMinutes: widget.recipe.durationMinutes,
                        calories: widget.recipe.calories,
                        protein: widget.recipe.nutritionRange?.proteinDisplay,
                        price: widget.recipe.price,
                        saving: _totalSaving > 0 ? _totalSaving : null,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _FadeSlideIn(
                      delayMs: 120,
                      child: _SectionShell(
                        title: 'Zutaten',
                        trailing: _isLoadingOffers
                            ? const _InlineLoadingPill(label: 'Angebote…')
                            : null,
                        child: ingredientItems.isEmpty
                            ? const _EmptyCard(text: 'Keine Zutaten verfügbar')
                            : Column(
                                children: ingredientItems
                                    .map((vm) => _ReadonlyIngredientRow(vm: vm))
                                    .toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (hasSteps)
                      _FadeSlideIn(
                        delayMs: 180,
                        child: _SectionShell(
                          title: 'Zubereitung',
                          child: Column(
                            children: widget.recipe.steps!
                                .asMap()
                                .entries
                                .map((e) => _StepCard(stepNumber: e.key + 1, text: e.value))
                                .toList(),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
          _StickyBottomCTA(
            primaryLabel: 'Zur Einkaufsliste hinzufügen',
            secondaryLabel: 'Zum Planer',
            onPrimary: _addToPlan, // Logik unverändert (bestehender CTA)
            onSecondary: _addToPlan,
            saving: _totalSaving > 0 ? _totalSaving : null,
          ),
        ],
      ),
    );
  }
}

class _IngredientViewModel {
  final int index;
  final String name;
  final Offer? offer;

  const _IngredientViewModel({
    required this.index,
    required this.name,
    required this.offer,
  });

  bool get isInOffer => offer != null && (offer!.price > 0);
}

class _HeroHeader extends StatelessWidget {
  final Recipe recipe;
  final String marketLabel;
  final bool isLoadingOffers;
  final VoidCallback onBack;
  final VoidCallback onShare;

  const _HeroHeader({
    required this.recipe,
    required this.marketLabel,
    required this.isLoadingOffers,
    required this.onBack,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = recipe.resolvedHeroImageUrlForUi;

    return SizedBox(
      height: 340,
      child: Stack(
        fit: StackFit.expand,
          children: [
          Hero(
            tag: 'recipe-hero-${recipe.id}',
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              child: (imagePath != null && imagePath.isNotEmpty)
                  ? (imagePath.startsWith('assets/')
                      ? Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _HeroFallback(),
                        )
                      : Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _HeroFallback(),
                        ))
                  : _HeroFallback(),
            ),
          ),
          // Subtle bottom gradient for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Floating controls
          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            left: 16,
            child: _GlassIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            right: 16,
            child: _GlassIconButton(
              icon: Icons.ios_share_rounded,
              onTap: onShare,
            ),
          ),
          // Market chip
          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            right: 16 + 44 + 10,
            child: _GlassChip(
              label: marketLabel,
              leading: isLoadingOffers ? Icons.sync_rounded : Icons.store_rounded,
            ),
          ),
          // Title in image (bottom-left)
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -0.6,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEFEF),
      child: const Center(
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 64,
          color: Color(0xFFB6B6B6),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final IconData? leading;

  const _GlassChip({
    required this.label,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(leading, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TitleBlock({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
            letterSpacing: -0.8,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7A7A7A),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _QuickFactsRow extends StatelessWidget {
  final int? durationMinutes;
  final int? calories;
  final String? protein;
  final double? price;
  final double? saving;

  const _QuickFactsRow({
    required this.durationMinutes,
    required this.calories,
    required this.protein,
    required this.price,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    String dashIfEmpty(String? v) => (v == null || v.isEmpty) ? '—' : v;
    String dashIfNullNum(num? v, {String suffix = ''}) => (v == null) ? '—' : '$v$suffix';

    return Row(
      children: [
        Expanded(
          child: _FactCard(
            icon: Icons.schedule_rounded,
            label: 'Dauer',
            value: durationMinutes != null ? '${durationMinutes} min' : '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FactCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Kalorien',
            value: dashIfNullNum(calories),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FactCard(
            icon: Icons.fitness_center_rounded,
            label: 'Protein',
            value: dashIfEmpty(protein),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FactCard(
            icon: Icons.payments_rounded,
            label: 'Preis',
            value: price != null ? '${price!.toStringAsFixed(2)} €' : '—',
            accent: saving != null ? const Color(0xFF18A25D) : null,
            hint: saving != null ? '-${saving!.toStringAsFixed(2)}€' : null,
          ),
        ),
      ],
    );
  }
}

class _FactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  final String? hint;

  const _FactCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? const Color(0xFF111111);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF000000).withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: a.withOpacity(0.9)),
              const Spacer(),
              if (hint != null)
                Text(
                  hint!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: a,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A8A8A),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: a,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF000000).withOpacity(0.05), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _InlineLoadingPill extends StatelessWidget {
  final String label;
  const _InlineLoadingPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111111).withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF000000).withOpacity(0.05), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A5A5A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyIngredientRow extends StatelessWidget {
  final _IngredientViewModel vm;
  const _ReadonlyIngredientRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final isInOffer = vm.isInOffer;
    final badgeColor = isInOffer ? const Color(0xFF18A25D) : const Color(0xFF9A9A9A);
    final badgeLabel = isInOffer ? 'Im Angebot' : 'Basis';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF000000).withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          _ReadonlyCheckbox(checked: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TinyPill(label: badgeLabel, color: badgeColor),
                    if (isInOffer && vm.offer?.price != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${vm.offer!.price.toStringAsFixed(2)} €',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF18A25D),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyCheckbox extends StatelessWidget {
  final bool checked;
  const _ReadonlyCheckbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF111111) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? const Color(0xFF111111) : const Color(0xFFCCCCCC),
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : null,
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String label;
  final Color color;
  const _TinyPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String text;

  const _StepCard({
    required this.stepNumber,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF000000).withOpacity(0.05), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Container(
              width: 28,
              height: 28,
                decoration: BoxDecoration(
                color: const Color(0xFF111111).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
                    Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222222),
                  height: 1.5,
                ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7A7A7A),
        ),
      ),
    );
  }
}

class _StickyBottomCTA extends StatelessWidget {
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final double? saving;

  const _StickyBottomCTA({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF000000).withOpacity(0.06), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _PrimaryCTAButton(
                  label: primaryLabel,
                  onTap: onPrimary,
                  subtitle: saving != null ? '${saving!.toStringAsFixed(2)} € sparen' : null,
                ),
              ),
              const SizedBox(width: 10),
              _SecondaryIconCTA(
                icon: Icons.calendar_month_rounded,
                onTap: onSecondary,
                tooltip: secondaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryCTAButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _PrimaryCTAButton({
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryIconCTA extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _SecondaryIconCTA({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF111111).withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF000000).withOpacity(0.06), width: 1),
          ),
          child: Icon(icon, color: const Color(0xFF111111), size: 22),
        ),
      ),
    );
  }
}

class _ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleTap({required this.child, required this.onTap});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _down ? 0.98 : 1.0,
        child: widget.child,
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const _FadeSlideIn({
    required this.child,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    // UI-only: simple fade+slide on first build (no scroll tracking, no extra packages)
    return FutureBuilder<void>(
      future: Future<void>.delayed(Duration(milliseconds: delayMs)),
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          opacity: ready ? 1.0 : 0.0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            offset: ready ? Offset.zero : const Offset(0, 0.02),
            child: child,
          ),
        );
      },
    );
  }
}
