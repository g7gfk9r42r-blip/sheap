import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/grocify_theme.dart';

class WelcomeStreakSheet extends StatefulWidget {
  final String? name;
  final int streakDays;

  const WelcomeStreakSheet({
    super.key,
    required this.name,
    required this.streakDays,
  });

  @override
  State<WelcomeStreakSheet> createState() => _WelcomeStreakSheetState();
}

class _WelcomeStreakSheetState extends State<WelcomeStreakSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _flameScale;
  late final Animation<double> _flameOpacity;
  late final Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _flameScale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    _flameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.05, 0.65, curve: Curves.easeOut)),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = (widget.name ?? '').trim();
    const headline = 'Schön dich zu sehen';
    final subtitle = n.isEmpty ? null : n;
    final days = widget.streakDays < 0 ? 0 : widget.streakDays;
    final dayLabel = days == 1 ? 'Tag' : 'Tage';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.55)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/Logo Jawoll/logo.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 28, height: 28),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            headline,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: GrocifyTheme.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: GrocifyTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            GrocifyTheme.warning.withOpacity(0.18),
                            GrocifyTheme.primary.withOpacity(0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GrocifyTheme.border.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _c,
                            builder: (context, _) {
                              return Opacity(
                                opacity: _flameOpacity.value,
                                child: Transform.scale(
                                  scale: 0.92 + (_flameScale.value * 0.10),
                                  child: Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.55),
                                      boxShadow: [
                                        BoxShadow(
                                          color: GrocifyTheme.warning.withOpacity(0.22),
                                          blurRadius: 26,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: const Center(child: Text('🔥', style: TextStyle(fontSize: 34))),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dein Streak',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: GrocifyTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(begin: 0, end: days),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return Text(
                                      '🔥 $value $dayLabel',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: GrocifyTheme.textPrimary,
                                        letterSpacing: -0.6,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: GrocifyTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Weiter',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


