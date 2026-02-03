/// Preferences Step - Ernährung & Präferenzen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';
import '../models/user_profile_local.dart';

class PreferencesStep extends StatefulWidget {
  final UserProfileLocal profile;
  final Function(UserProfileLocal) onUpdate;
  final VoidCallback onNext;

  const PreferencesStep({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<PreferencesStep> {
  late Set<DietPreference> _selectedPreferences;
  final _allergiesController = TextEditingController();
  int? _preferredCookingTime;

  @override
  void initState() {
    super.initState();
    _selectedPreferences = Set.from(widget.profile.dietPreferences);
    _allergiesController.text = widget.profile.allergies ?? '';
    _preferredCookingTime = widget.profile.preferredCookingTime;
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    super.dispose();
  }

  void _updateProfile() {
    widget.onUpdate(
      widget.profile.copyWith(
        dietPreferences: _selectedPreferences,
        allergies: _allergiesController.text.isEmpty ? null : _allergiesController.text,
        preferredCookingTime: _preferredCookingTime,
      ),
    );
  }

  void _togglePreference(DietPreference pref) {
    setState(() {
      if (_selectedPreferences.contains(pref)) {
        _selectedPreferences.remove(pref);
      } else {
        _selectedPreferences.add(pref);
      }
    });
    _updateProfile();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GrocifyTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: GrocifyTheme.spaceXL),
            
            // Header
            const Text(
              'Deine Präferenzen',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceSM),
            Text(
              'Hilf uns, die passenden Rezepte für dich zu finden',
              style: TextStyle(
                fontSize: 16,
                color: GrocifyTheme.textSecondary,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceXXXL),
            
            // Diet Preferences
            const Text(
              'Ernährungsweise',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            Wrap(
              spacing: GrocifyTheme.spaceMD,
              runSpacing: GrocifyTheme.spaceMD,
              children: [
                _buildPreferenceChip(DietPreference.vegetarian, 'Vegetarisch'),
                _buildPreferenceChip(DietPreference.vegan, 'Vegan'),
                _buildPreferenceChip(DietPreference.lowCarb, 'Low Carb'),
                _buildPreferenceChip(DietPreference.highProtein, 'High Protein'),
                _buildPreferenceChip(DietPreference.lactoseFree, 'Laktosefrei'),
                _buildPreferenceChip(DietPreference.glutenFree, 'Glutenfrei'),
              ],
            ),
            
            const SizedBox(height: GrocifyTheme.spaceXXXL),
            
            // Allergies
            const Text(
              'Allergien (optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceSM),
            TextField(
              controller: _allergiesController,
              decoration: const InputDecoration(
                hintText: 'z.B. Nüsse, Erdnüsse, Fisch',
              ),
              maxLines: 2,
              onChanged: (_) => _updateProfile(),
            ),
            
            const SizedBox(height: GrocifyTheme.spaceXXXL),
            
            // Cooking Time
            const Text(
              'Bevorzugte Kochzeit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            Row(
              children: [
                Expanded(child: _buildCookingTimeOption(10, 20, '10-20 min')),
                const SizedBox(width: GrocifyTheme.spaceMD),
                Expanded(child: _buildCookingTimeOption(20, 40, '20-40 min')),
                const SizedBox(width: GrocifyTheme.spaceMD),
                Expanded(child: _buildCookingTimeOption(40, null, '40+ min')),
              ],
            ),
            
            const Spacer(),
            
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

  Widget _buildPreferenceChip(DietPreference pref, String label) {
    final isSelected = _selectedPreferences.contains(pref);
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _togglePreference(pref),
      selectedColor: GrocifyTheme.primary.withOpacity(0.2),
      checkmarkColor: GrocifyTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? GrocifyTheme.primary : GrocifyTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildCookingTimeOption(int min, int? max, String label) {
    final value = max != null ? (min + max) ~/ 2 : 45;
    final isSelected = _preferredCookingTime == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _preferredCookingTime = value;
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
          label,
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

