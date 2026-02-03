import 'package:flutter/foundation.dart';

import '../../../core/storage/customer_storage.dart';
import '../../auth/data/models/user_account.dart';

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  final _storage = CustomerStorage.instance;

  Future<UserProfile?> loadProfile(String uid) async {
    final json = await _storage.readJson(CustomerPaths.userFile(uid));
    if (json == null) return null;
    final user = UserAccount.fromJson(json);
    return user.profile;
  }

  Future<void> updateProfile(
    String uid, {
    String? displayName,
    String? diet,
    List<String>? allergies,
    List<String>? goals,
    List<String>? favoriteMarkets,
  }) async {
    final json = await _storage.readJson(CustomerPaths.userFile(uid));
    if (json == null) return;
    final user = UserAccount.fromJson(json);
    final updatedProfile = user.profile.copyWith(
      displayName: displayName,
      diet: diet,
      allergies: allergies,
      goals: goals,
      favoriteMarkets: favoriteMarkets,
    );
    final updated = user.copyWith(profile: updatedProfile);
    await _storage.writeJson(CustomerPaths.userFile(uid), updated.toJson());
    if (kDebugMode) debugPrint('👤 Profile updated: uid=$uid diet=${updatedProfile.diet} goals=${updatedProfile.goals}');
  }
}


