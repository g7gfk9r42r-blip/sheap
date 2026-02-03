/// Onboarding Flow - Main Screen für Onboarding
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import '../../core/theme/grocify_theme.dart';
import 'onboarding_controller.dart';
import 'onboarding_repository.dart';
import 'models/user_profile_local.dart';
import 'steps/intro_step.dart';
import 'steps/name_step.dart';
import 'steps/quick_prefs_step.dart';
import 'steps/supermarket_step.dart';
import 'steps/success_step.dart';
import '../auth/data/auth_service_local.dart';
import '../customer/data/customer_data_store.dart';
import '../customer/domain/models/customer_preferences.dart';
import '../user/data/user_profile_service.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late OnboardingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OnboardingController();
    _controller.addListener(_onControllerChanged);
    _loadPackageInfo();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        _controller.updateProfile((p) => p.copyWith(
          appVersion: '${info.version} (${info.buildNumber})',
        ));
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _completeOnboarding() async {
    final profile = _controller.profile.copyWith(
      deviceLocale: Localizations.localeOf(context).toString(),
    );
    
    await OnboardingRepository.saveUserProfile(profile);
    await OnboardingRepository.setOnboardingCompleted(true);

    // Apply onboarding choices to the signed-in user (local files only, no Firestore).
    try {
      final user = await AuthServiceLocal.instance.getCurrentUser();
      if (user != null) {
        final diet = profile.dietPreferences.contains(DietPreference.vegan)
            ? 'vegan'
            : (profile.dietPreferences.contains(DietPreference.vegetarian) ? 'vegetarian' : 'none');

        final goal = switch (profile.goalType) {
          GoalType.loseWeight => 'lose_weight',
          GoalType.maintainWeight => 'maintain_weight',
          GoalType.gainWeight => 'gain_weight',
          null => null,
        };

        await UserProfileService.instance.updateProfile(
          user.uid,
          displayName: (profile.name ?? '').trim().isEmpty ? null : profile.name!.trim(),
          diet: diet,
          goals: goal == null ? null : [goal],
          allergies: (profile.allergies ?? '')
              .split(RegExp(r'[,;]'))
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toList(),
          favoriteMarkets: profile.favoriteSupermarkets.isEmpty ? null : profile.favoriteSupermarkets,
        );

        final store = CustomerDataStore.instance;
        final existing = await store.loadPreferences();
        await store.savePreferences(
          CustomerPreferences(
            diet: CustomerDietX.fromString(diet),
            primaryGoal: goal,
            dislikedIngredients: existing.dislikedIngredients,
            allergens: (profile.allergies ?? '')
                .split(RegExp(r'[,;]'))
                .map((s) => s.trim().toLowerCase())
                .where((s) => s.isNotEmpty)
                .toList(),
            calorieGoal: existing.calorieGoal,
            language: existing.language,
            personalizationEnabled: true,
          ),
        );
      }
    } catch (_) {
      // Never block onboarding completion on persistence.
    }
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Widget _buildProgressIndicator() {
    final progress = (_controller.currentStep + 1) / _controller.totalSteps;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: GrocifyTheme.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: GrocifyTheme.spaceSM),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: GrocifyTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(GrocifyTheme.primary),
            minHeight: 3,
          ),
          const SizedBox(height: GrocifyTheme.spaceXS),
          Text(
            '${_controller.currentStep + 1} / ${_controller.totalSteps}',
            style: TextStyle(
              fontSize: 12,
              color: GrocifyTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_controller.currentStep) {
      case 0:
        return IntroStep(onNext: _controller.nextStep);
      case 1:
        return NameStep(
          profile: _controller.profile,
          onUpdate: (p) => _controller.updateProfile((_) => p),
          onNext: _controller.nextStep,
          onSkip: _controller.nextStep,
        );
      case 2:
        return QuickPrefsStep(
          profile: _controller.profile,
          onUpdate: (p) => _controller.updateProfile((_) => p),
          onNext: _controller.nextStep,
          onSkip: _controller.nextStep,
        );
      case 3:
        return SupermarketStep(
          profile: _controller.profile,
          onUpdate: (p) => _controller.updateProfile((_) => p),
          onNext: _controller.nextStep,
          onSkip: _controller.nextStep,
        );
      case 4:
        return SuccessStep(onComplete: _completeOnboarding);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: Column(
        children: [
          // Progress Indicator (nicht bei Intro und Success)
          if (_controller.currentStep > 0 && _controller.currentStep < 4)
            _buildProgressIndicator(),
          
          // Current Step
          Expanded(
            child: _buildCurrentStep(),
          ),
        ],
      ),
    );
  }
}

