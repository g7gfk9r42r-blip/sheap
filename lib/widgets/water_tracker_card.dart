import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Water Tracker Card Widget
/// 
/// Displays current water intake, goal, and visual cups representation.
/// 
/// Interaction:
/// - Tap on any cup to fill all cups up to that index (e.g., tap cup 5 → fills cups 1-5)
/// - Tap on a lower cup to reduce the fill level (e.g., tap cup 3 when cup 5 is filled → reduces to cup 3)
/// - All state changes are smoothly animated with premium UX feedback
class WaterTrackerCard extends StatefulWidget {
  final double currentLitres;
  final double goalLitres;
  final int totalCups;
  final Function(int cupIndex) onCupTap;

  const WaterTrackerCard({
    super.key,
    required this.currentLitres,
    required this.goalLitres,
    required this.totalCups,
    required this.onCupTap,
  });

  @override
  State<WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends State<WaterTrackerCard> {
  double _previousLitres = 0.0;
  int? _lastTappedCupIndex;
  final Map<int, bool> _cupAnimationStates = {};

  @override
  void initState() {
    super.initState();
    _previousLitres = widget.currentLitres;
  }

  @override
  void didUpdateWidget(WaterTrackerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Detect skip (jump forward or backward)
    final oldCups = (oldWidget.currentLitres / 0.25).floor();
    final newCups = (widget.currentLitres / 0.25).floor();
    final diff = (newCups - oldCups).abs();
    
    if (diff > 1 && _lastTappedCupIndex != null) {
      // Staggered wave animation for skip
      _animateCupsWave(oldCups, newCups);
    }
    
    _previousLitres = widget.currentLitres;
  }

  void _animateCupsWave(int startIndex, int endIndex) {
    final direction = endIndex > startIndex ? 1 : -1;
    final count = (endIndex - startIndex).abs();
    
    for (int i = 0; i < count; i++) {
      final cupIndex = startIndex + (i * direction);
      Future.delayed(Duration(milliseconds: 60 + (i * 20)), () {
        if (mounted) {
          setState(() {
            _cupAnimationStates[cupIndex] = true;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _cupAnimationStates[cupIndex] = false;
              });
            }
          });
        }
      });
    }
  }

  void _handleCupTap(int cupIndex) {
    _lastTappedCupIndex = cupIndex;
    
    final currentCups = (widget.currentLitres / 0.25).floor();
    final targetCups = cupIndex + 1;
    final diff = (targetCups - currentCups).abs();
    
    // Haptic feedback
    if (diff > 1) {
      // Skip detected
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    
    // Trigger wave animation if skip
    if (diff > 1) {
      _animateCupsWave(currentCups, targetCups);
    }
    
    widget.onCupTap(cupIndex);
  }

  @override
  Widget build(BuildContext context) {
    const litresPerCup = 0.25;
    final filledCups = (widget.currentLitres / litresPerCup).floor();
    final partialFill = (widget.currentLitres / litresPerCup) - filledCups;
    final progress = (widget.currentLitres / widget.goalLitres).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE7E5E4).withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated current amount display
          _AnimatedCurrentAmountSection(
            currentLitres: widget.currentLitres,
            previousLitres: _previousLitres,
          ),
          const SizedBox(height: 24),
          
          // Cups visualization with smooth animations
          _CupsSection(
            filledCups: filledCups,
            partialFill: partialFill,
            onCupTap: _handleCupTap,
            animationStates: _cupAnimationStates,
          ),
          const SizedBox(height: 16),
          
          // Animated progress bar
          _AnimatedProgressBar(
            progress: progress,
            previousProgress: (_previousLitres / widget.goalLitres).clamp(0.0, 1.0),
          ),
        ],
      ),
    );
  }
}

/// Animated Current Amount Section: Smoothly animates the displayed litres
class _AnimatedCurrentAmountSection extends StatelessWidget {
  final double currentLitres;
  final double previousLitres;

  const _AnimatedCurrentAmountSection({
    required this.currentLitres,
    required this.previousLitres,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: previousLitres, end: currentLitres),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              ),
            );
          },
          child: Text(
            '${value.toStringAsFixed(2)} L',
            key: ValueKey(value),
            style: const TextStyle(
              color: Color(0xFF1C1917), // stone-900
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        );
      },
    );
  }
}

/// Cups Section: Visual representation with smoothly animated cups
class _CupsSection extends StatelessWidget {
  final int filledCups;
  final double partialFill;
  final Function(int cupIndex) onCupTap;
  final Map<int, bool> animationStates;

  const _CupsSection({
    required this.filledCups,
    required this.partialFill,
    required this.onCupTap,
    required this.animationStates,
  });

  @override
  Widget build(BuildContext context) {
    const firstTwoRowsCups = 10; // 5 + 5
    final nextEmptyCupIndex = filledCups + (partialFill > 0 ? 1 : 0);
    
    final rows = <Widget>[];
    
    if (filledCups < firstTwoRowsCups) {
      // Top row: 5 cups (0-4)
      final topRowCups = List.generate(5, (index) {
        final isFilled = index < filledCups;
        final isPartiallyFilled = index == filledCups && partialFill > 0;
        final isPlusButton = index == nextEmptyCupIndex;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _AnimatedWaterCup(
              cupIndex: index,
              filled: isFilled,
              partiallyFilled: isPartiallyFilled,
              partialFillAmount: isPartiallyFilled ? partialFill : 0.0,
              isPlusButton: isPlusButton,
              onTap: () => onCupTap(index),
              isAnimating: animationStates[index] ?? false,
            ),
          ),
        );
      });
      
      // Bottom row: 5 cups (5-9)
      final bottomRowCups = List.generate(5, (index) {
        final cupIndex = index + 5;
        final isFilled = cupIndex < filledCups;
        final isPartiallyFilled = cupIndex == filledCups && partialFill > 0;
        final isPlusButton = cupIndex == nextEmptyCupIndex;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _AnimatedWaterCup(
              cupIndex: cupIndex,
              filled: isFilled,
              partiallyFilled: isPartiallyFilled,
              partialFillAmount: isPartiallyFilled ? partialFill : 0.0,
              isPlusButton: isPlusButton,
              onTap: () => onCupTap(cupIndex),
              isAnimating: animationStates[cupIndex] ?? false,
            ),
          ),
        );
      });
      
      rows.add(Row(children: topRowCups));
      rows.add(const SizedBox(height: 12));
      rows.add(Row(children: bottomRowCups));
    } else {
      // First two rows fully filled (10 cups)
      final topRowCups = List.generate(5, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _AnimatedWaterCup(
              cupIndex: index,
              filled: true,
              partiallyFilled: false,
              partialFillAmount: 0.0,
              isPlusButton: false,
              onTap: () => onCupTap(index),
              isAnimating: animationStates[index] ?? false,
            ),
          ),
        );
      });
      
      final bottomRowCups = List.generate(5, (index) {
        final cupIndex = index + 5;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _AnimatedWaterCup(
              cupIndex: cupIndex,
              filled: true,
              partiallyFilled: false,
              partialFillAmount: 0.0,
              isPlusButton: false,
              onTap: () => onCupTap(cupIndex),
            ),
          ),
        );
      });
      
      rows.add(Row(children: topRowCups));
      rows.add(const SizedBox(height: 12));
      rows.add(Row(children: bottomRowCups));
      
      // Extra rows beyond 10 cups
      final extraCups = filledCups - firstTwoRowsCups;
      final needsMoreRows = extraCups > 5;
      
      rows.add(const SizedBox(height: 12));
      final firstExtraRowCups = <Widget>[];
      
      for (int i = 0; i < 5; i++) {
        final cupIndex = firstTwoRowsCups + i;
        final isFilled = cupIndex < filledCups;
        final isPlusButton = cupIndex == nextEmptyCupIndex;
        
        firstExtraRowCups.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _AnimatedWaterCup(
                cupIndex: cupIndex,
                filled: isFilled,
                partiallyFilled: false,
                partialFillAmount: 0.0,
                isPlusButton: isPlusButton,
                onTap: () => onCupTap(cupIndex),
                isAnimating: animationStates[cupIndex] ?? false,
              ),
            ),
          ),
        );
      }
      rows.add(Row(children: firstExtraRowCups));
      
      if (needsMoreRows) {
        final remainingCups = extraCups - 5;
        final additionalRows = (remainingCups / 5).ceil() + 1;
        
        for (int rowIndex = 0; rowIndex < additionalRows; rowIndex++) {
          rows.add(const SizedBox(height: 12));
          
          final rowCups = <Widget>[];
          final rowStartIndex = firstTwoRowsCups + 5 + (rowIndex * 5);
          
          for (int i = 0; i < 5; i++) {
            final cupIndex = rowStartIndex + i;
            final isFilled = cupIndex < filledCups;
            final isPlusButton = cupIndex == nextEmptyCupIndex;
            
            rowCups.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _AnimatedWaterCup(
                    cupIndex: cupIndex,
                    filled: isFilled,
                    partiallyFilled: false,
                    partialFillAmount: 0.0,
                    isPlusButton: isPlusButton,
                    onTap: () => onCupTap(cupIndex),
                  ),
                ),
              ),
            );
          }
          
          rows.add(Row(children: rowCups));
        }
      }
    }
    
    return Column(
      children: rows,
    );
  }
}

/// Individual Water Cup Widget with smooth animations
class _AnimatedWaterCup extends StatefulWidget {
  final int cupIndex;
  final bool filled;
  final bool partiallyFilled;
  final double partialFillAmount;
  final bool isPlusButton;
  final VoidCallback onTap;
  final bool isAnimating;

  const _AnimatedWaterCup({
    required this.cupIndex,
    required this.filled,
    required this.partiallyFilled,
    required this.partialFillAmount,
    required this.isPlusButton,
    required this.onTap,
    this.isAnimating = false,
  });

  @override
  State<_AnimatedWaterCup> createState() => _AnimatedWaterCupState();
}

class _AnimatedWaterCupState extends State<_AnimatedWaterCup>
    with TickerProviderStateMixin {
  late AnimationController _tapAnimationController;
  late AnimationController _fillAnimationController;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _fillScaleAnimation;
  late Animation<double> _glowAnimation;
  bool _wasFilled = false;

  @override
  void initState() {
    super.initState();
    _wasFilled = widget.filled;
    
    _tapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _tapScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _tapAnimationController,
      curve: Curves.easeOut,
    ));
    
    _fillAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fillScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fillAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fillAnimationController,
      curve: Curves.easeOut,
    ));
    
    if (widget.filled && !_wasFilled) {
      _fillAnimationController.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedWaterCup oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animate fill/empty transitions
    if (widget.filled && !oldWidget.filled) {
      _fillAnimationController.forward(from: 0.0);
    } else if (!widget.filled && oldWidget.filled) {
      _fillAnimationController.reverse();
    }
    
    // Trigger glow animation
    if (widget.isAnimating) {
      _fillAnimationController.forward(from: 0.0).then((_) {
        _fillAnimationController.reverse();
      });
    }
    
    _wasFilled = widget.filled;
  }

  @override
  void dispose() {
    _tapAnimationController.dispose();
    _fillAnimationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _tapAnimationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _tapAnimationController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _tapAnimationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.filled || widget.partiallyFilled || widget.isPlusButton;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _tapScaleAnimation,
        builder: (context, child) {
          return AnimatedBuilder(
            animation: _fillAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _tapScaleAnimation.value * _fillScaleAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: widget.isPlusButton
                        ? null
                        : isActive
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF7DD3FC), // sky-300
                                  const Color(0xFF60A5FA), // blue-400
                                  const Color(0xFF3B82F6), // blue-500
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              )
                            : null,
                    color: widget.isPlusButton
                        ? const Color(0xFF10B981) // emerald-500
                        : (!isActive)
                            ? Colors.transparent
                            : null,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: widget.isPlusButton
                          ? const Color(0xFF10B981) // emerald-500
                          : isActive
                              ? const Color(0xFF3B82F6).withOpacity(0.8)
                              : const Color(0xFFE7E5E4), // stone-200
                      width: widget.isPlusButton || isActive ? 2.5 : 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: (widget.isAnimating
                                      ? const Color(0xFF10B981) // emerald glow
                                      : const Color(0xFF60A5FA))
                                  .withOpacity(
                                widget.filled
                                    ? (0.3 + (_glowAnimation.value * 0.2))
                                    : 0.2,
                              ),
                              blurRadius: widget.filled
                                  ? (12 + (_glowAnimation.value * 8))
                                  : 8,
                              offset: const Offset(0, 4),
                              spreadRadius: widget.isAnimating ? 2 : 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
              child: Stack(
                children: [
                  // Animated partial fill indicator
                  if (widget.partiallyFilled)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 52 * widget.partialFillAmount,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF7DD3FC), // sky-300
                              Color(0xFF60A5FA), // blue-400
                              Color(0xFF3B82F6), // blue-500
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  
                  // Icon with smooth opacity transition
                  Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isActive ? 1.0 : 0.6,
                      child: widget.isPlusButton
                          ? const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : isActive
                              ? Icon(
                                  Icons.water_drop_rounded,
                                  color: Colors.white.withOpacity(0.95),
                                  size: widget.filled ? 24 : 22, // Slightly larger when fully filled
                                )
                              : const Icon(
                                  Icons.water_drop_outlined,
                                  color: Color(0xFFA8A29E), // stone-400
                                  size: 22,
                                ),
                    ),
                  ),
                ],
              ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Animated Progress Bar: Smoothly animates width changes
class _AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final double previousProgress;

  const _AnimatedProgressBar({
    required this.progress,
    required this.previousProgress,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: previousProgress, end: progress),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE7E5E4).withOpacity(0.5), // stone-200
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF60A5FA), // blue-400
                    Color(0xFF10B981), // emerald-500
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
