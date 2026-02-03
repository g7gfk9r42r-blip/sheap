/// Goal Step - Gewichts-Ziele
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';
import '../models/user_profile_local.dart';

class GoalStep extends StatefulWidget {
  final UserProfileLocal profile;
  final Function(UserProfileLocal) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const GoalStep({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<GoalStep> createState() => _GoalStepState();
}

class _GoalStepState extends State<GoalStep> {
  final _startWeightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  GoalType? _selectedGoalType;

  @override
  void initState() {
    super.initState();
    _startWeightController.text = widget.profile.startWeight?.toString() ?? '';
    _targetWeightController.text = widget.profile.targetWeight?.toString() ?? '';
    _selectedGoalType = widget.profile.goalType;
  }

  @override
  void dispose() {
    _startWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _updateProfile() {
    final startWeight = double.tryParse(_startWeightController.text);
    final targetWeight = double.tryParse(_targetWeightController.text);
    
    widget.onUpdate(
      widget.profile.copyWith(
        startWeight: startWeight,
        targetWeight: targetWeight,
        goalType: _selectedGoalType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: GrocifyTheme.screenPadding,
              right: GrocifyTheme.screenPadding,
              top: GrocifyTheme.spaceXL,
              bottom: MediaQuery.of(context).viewInsets.bottom + GrocifyTheme.spaceLG,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Deine Ziele',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: GrocifyTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: GrocifyTheme.spaceSM),
                Text(
                  'Alle Angaben sind optional. Du kannst jederzeit später anpassen.',
                  style: TextStyle(
                    fontSize: 16,
                    color: GrocifyTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: GrocifyTheme.spaceXXXL),
                
                // Startgewicht
                _buildWeightInput(
                  label: 'Startgewicht (kg)',
                  controller: _startWeightController,
                  hint: 'z.B. 75',
                ),
                
                const SizedBox(height: GrocifyTheme.spaceXL),
                
                // Zielgewicht
                _buildWeightInput(
                  label: 'Zielgewicht (kg)',
                  controller: _targetWeightController,
                  hint: 'z.B. 70',
                ),
                
                const SizedBox(height: GrocifyTheme.spaceXL),
                
                // Zieltyp
                const Text(
                  'Mein Ziel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: GrocifyTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: GrocifyTheme.spaceMD),
                
                _buildGoalOption(
                  type: GoalType.loseWeight,
                  label: 'Abnehmen',
                  icon: Icons.trending_down_rounded,
                ),
                const SizedBox(height: GrocifyTheme.spaceMD),
                _buildGoalOption(
                  type: GoalType.maintainWeight,
                  label: 'Gewicht halten',
                  icon: Icons.trending_flat_rounded,
                ),
                const SizedBox(height: GrocifyTheme.spaceMD),
                _buildGoalOption(
                  type: GoalType.gainWeight,
                  label: 'Zunehmen',
                  icon: Icons.trending_up_rounded,
                ),
                
                const SizedBox(height: GrocifyTheme.spaceXL),
                
                // Info Box
                Container(
                  padding: const EdgeInsets.all(GrocifyTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: GrocifyTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: GrocifyTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: GrocifyTheme.spaceSM),
                      Expanded(
                        child: Text(
                          'Alle Daten werden nur lokal auf deinem Gerät gespeichert.',
                          style: TextStyle(
                            fontSize: 13,
                            color: GrocifyTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: GrocifyTheme.spaceLG),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onSkip();
                        },
                        child: const Text('Überspringen'),
                      ),
                    ),
                    const SizedBox(width: GrocifyTheme.spaceMD),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          _updateProfile();
                          HapticFeedback.lightImpact();
                          widget.onNext();
                        },
                        child: const Text('Weiter'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: GrocifyTheme.spaceLG),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeightInput({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: GrocifyTheme.textPrimary,
          ),
        ),
        const SizedBox(height: GrocifyTheme.spaceSM),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: 'kg',
          ),
          onChanged: (_) => _updateProfile(),
        ),
      ],
    );
  }

  Widget _buildGoalOption({
    required GoalType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedGoalType == type;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedGoalType = type;
        });
        _updateProfile();
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
      child: Container(
        padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
        decoration: BoxDecoration(
          color: isSelected
              ? GrocifyTheme.primary.withOpacity(0.1)
              : GrocifyTheme.surface,
          border: Border.all(
            color: isSelected ? GrocifyTheme.primary : GrocifyTheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? GrocifyTheme.primary : GrocifyTheme.textSecondary,
            ),
            const SizedBox(width: GrocifyTheme.spaceMD),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? GrocifyTheme.primary : GrocifyTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: GrocifyTheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
