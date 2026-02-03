/// Water Step - Wasserziel
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';
import '../models/user_profile_local.dart';

class WaterStep extends StatefulWidget {
  final UserProfileLocal profile;
  final Function(UserProfileLocal) onUpdate;
  final VoidCallback onNext;

  const WaterStep({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<WaterStep> createState() => _WaterStepState();
}

class _WaterStepState extends State<WaterStep> {
  late double _waterGoalMl;
  bool _enableReminder = false;

  @override
  void initState() {
    super.initState();
    _waterGoalMl = widget.profile.waterGoalMl;
  }

  void _updateProfile() {
    widget.onUpdate(
      widget.profile.copyWith(waterGoalMl: _waterGoalMl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liters = _waterGoalMl / 1000.0;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: GrocifyTheme.spaceXL),
            
            // Header
            const Text(
              'Dein Wasserziel',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceSM),
            Text(
              'Wie viel Wasser möchtest du täglich trinken?',
              style: TextStyle(
                fontSize: 16,
                color: GrocifyTheme.textSecondary,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceXXXL),
            
            // Value Display
            Center(
              child: Column(
                children: [
                  Text(
                    liters.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: GrocifyTheme.primary,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'Liter',
                    style: TextStyle(
                      fontSize: 20,
                      color: GrocifyTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceXXXL),
            
            // Slider
            Slider(
              value: _waterGoalMl,
              min: 1000,
              max: 5000,
              divisions: 40,
              label: '${liters.toStringAsFixed(1)} L',
              onChanged: (value) {
                setState(() {
                  _waterGoalMl = value;
                });
                _updateProfile();
                HapticFeedback.selectionClick();
              },
            ),
            
            // Quick Presets
            const SizedBox(height: GrocifyTheme.spaceXL),
            const Text(
              'Schnellauswahl',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            Row(
              children: [
                Expanded(child: _buildPresetButton(1.5)),
                const SizedBox(width: GrocifyTheme.spaceMD),
                Expanded(child: _buildPresetButton(2.0)),
                const SizedBox(width: GrocifyTheme.spaceMD),
                Expanded(child: _buildPresetButton(2.5)),
                const SizedBox(width: GrocifyTheme.spaceMD),
                Expanded(child: _buildPresetButton(3.0)),
              ],
            ),
            
            const Spacer(),
            
            // Reminder Toggle (Info only, actual notifications would be implemented later)
            Container(
              padding: const EdgeInsets.all(GrocifyTheme.spaceMD),
              decoration: BoxDecoration(
                color: GrocifyTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Erinnerungen aktivieren',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: GrocifyTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Erinnere mich daran, regelmäßig Wasser zu trinken',
                          style: TextStyle(
                            fontSize: 12,
                            color: GrocifyTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enableReminder,
                    onChanged: (value) {
                      setState(() {
                        _enableReminder = value;
                      });
                      HapticFeedback.selectionClick();
                      // Note: Actual notification setup would happen later
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceLG),
            
            // Next Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _updateProfile();
                  HapticFeedback.lightImpact();
                  widget.onNext();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceLG),
                ),
                child: const Text(
                  'Weiter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceLG),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(double liters) {
    final ml = (liters * 1000).round();
    final isSelected = (_waterGoalMl / 1000).roundToDouble() == liters;
    
    return InkWell(
      onTap: () {
        setState(() {
          _waterGoalMl = ml.toDouble();
        });
        _updateProfile();
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceMD),
        decoration: BoxDecoration(
          color: isSelected
              ? GrocifyTheme.primary.withOpacity(0.1)
              : GrocifyTheme.surface,
          border: Border.all(
            color: isSelected ? GrocifyTheme.primary : GrocifyTheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
        ),
        child: Text(
          '${liters.toStringAsFixed(1)}L',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? GrocifyTheme.primary : GrocifyTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

