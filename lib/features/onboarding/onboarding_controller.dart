/// Onboarding Controller - Managed State für Onboarding Flow
import 'package:flutter/foundation.dart';
import 'models/user_profile_local.dart';

class OnboardingController extends ChangeNotifier {
  int _currentStep = 0;
  UserProfileLocal _profile = UserProfileLocal(waterGoalMl: 2000.0);

  int get currentStep => _currentStep;
  UserProfileLocal get profile => _profile;
  int get totalSteps => 5; // 0-4 (Intro, Name, QuickPrefs, Supermarket, Success)

  void updateProfile(UserProfileLocal Function(UserProfileLocal) updateFn) {
    _profile = updateFn(_profile);
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < totalSteps - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step < totalSteps) {
      _currentStep = step;
      notifyListeners();
    }
  }

  bool get canProceed {
    return true;
  }
}

