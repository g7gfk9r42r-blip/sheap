/// Intro Step - Cinematic Welcome Screen (EPIC & WERTSCHÄTZEND!)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';

class IntroStep extends StatefulWidget {
  final VoidCallback onNext;

  const IntroStep({
    super.key,
    required this.onNext,
  });

  @override
  State<IntroStep> createState() => _IntroStepState();
}

class _IntroStepState extends State<IntroStep> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GrocifyTheme.background,
              GrocifyTheme.background.withOpacity(0.96),
              GrocifyTheme.primary.withOpacity(0.16),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.03),
                    
                    // Animated Icon/Emoji (EPIC!)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color: GrocifyTheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: GrocifyTheme.border.withOpacity(0.75),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 26,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Text(
                            '🍽️',
                            style: TextStyle(fontSize: 72),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXXXL),
                    
                    // Headline (WERTSCHÄTZEND!)
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            const Text(
                              'Willkommen bei sheap',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: GrocifyTheme.textPrimary,
                                letterSpacing: -0.8,
                                height: 1.15,
                              ),
                            ),
                            
                            const SizedBox(height: GrocifyTheme.spaceLG),
                            
                            Text(
                              'Angebote rein.\nRezepte raus.\nWoche easy geplant.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: GrocifyTheme.textSecondary,
                                height: 1.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXXL),
                    
                    // Benefits (Epic Cards - Scrollable if needed)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            _buildBenefitCard('💰', 'Spare mehr Geld', 'Rezepte aus echten Angeboten'),
                            const SizedBox(height: GrocifyTheme.spaceMD),
                            _buildBenefitCard('⚡', 'Plane schneller', 'Wochenplan in Sekunden'),
                            const SizedBox(height: GrocifyTheme.spaceMD),
                            _buildBenefitCard('🎯', 'Iss gesünder', 'Personalisiert nach deinen Zielen'),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXXL),
                    
                    // CTA Button (Epic & Wertschätzend)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(GrocifyTheme.radiusXL),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            widget.onNext();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: GrocifyTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              vertical: GrocifyTheme.spaceXL,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GrocifyTheme.radiusXL),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Los geht\'s! 🚀',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: constraints.maxHeight * 0.03),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBenefitCard(String emoji, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
        border: Border.all(
          color: GrocifyTheme.border.withOpacity(0.60),
          width: 1,
        ),
        boxShadow: GrocifyTheme.shadowSM,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GrocifyTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
              border: Border.all(color: GrocifyTheme.primary.withOpacity(0.18)),
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 36),
            ),
          ),
          const SizedBox(width: GrocifyTheme.spaceLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: GrocifyTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GrocifyTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
