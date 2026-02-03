/// PremiumService (MVP / backendless)
/// - Mock purchase flow (plan: monthly_699)
/// - Persists under dates_from_costumors/premium/<uid>.json
/// - Also updates users/<uid>.json flags.is_premium
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/storage/customer_storage.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../auth/data/auth_service_local.dart';
import '../auth/data/models/user_account.dart';

class PremiumService extends ChangeNotifier {
  PremiumService._();
  static PremiumService? _instance;
  static PremiumService get instance => _instance ??= PremiumService._();

  static const String planMonthly699 = 'monthly_699';
  static const double priceEur = 6.99;
  static const String appleProductIdMonthly = 'sheap_premium_monthly_699';

  bool _premiumActive = false;
  bool _isLoading = false;
  String? _error;

  bool get premiumActive => _premiumActive;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (!FirebaseBootstrap.firebaseAvailable) {
        _premiumActive = false;
        if (kDebugMode) debugPrint('ℹ️ Premium: skipped (firebase unavailable)');
        return;
      }
      await refreshStatus();
      if (kDebugMode) debugPrint('💎 PremiumService init: active=$_premiumActive');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> getPremiumStatus(String uid) async {
    final json = await CustomerStorage.instance.readJson(CustomerPaths.premiumFile(uid));
    if (json == null) return false;
    return (json['status']?.toString() ?? 'inactive') == 'active';
  }

  Future<void> refreshStatus() async {
    if (!FirebaseBootstrap.firebaseAvailable) {
      _premiumActive = false;
      return;
    }
    final user = await AuthServiceLocal.instance.getCurrentUser();
    if (user == null) {
      _premiumActive = false;
      return;
    }
    _premiumActive = await getPremiumStatus(user.uid);
  }

  Future<void> purchaseMonthly({
    required String uid,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await CustomerStorage.instance.writeJson(CustomerPaths.premiumFile(uid), {
        'uid': uid,
        'plan': planMonthly699,
        'price_eur': priceEur,
        'status': 'active',
        'started_at': now,
        'payment_method': paymentMethod,
        'renewal': 'monthly',
      });

      // Update user flags
      final userJson = await CustomerStorage.instance.readJson(CustomerPaths.userFile(uid));
      if (userJson != null) {
        final u = UserAccount.fromJson(userJson);
        final updated = u.copyWith(
          flags: UserFlags(isPremium: true, welcomeSeen: u.flags.welcomeSeen),
        );
        await CustomerStorage.instance.writeJson(CustomerPaths.userFile(uid), updated.toJson());
      }

      _premiumActive = true;
      if (kDebugMode) debugPrint('💎 Premium purchase: uid=$uid method=$paymentMethod');
    } catch (e) {
      _error = 'Purchase fehlgeschlagen';
      if (kDebugMode) debugPrint('⚠️ Premium purchase error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _premiumActive = await getPremiumStatus(uid);
      if (kDebugMode) debugPrint('💎 Premium restore: uid=$uid active=$_premiumActive');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apple-only flow (StoreKit). For MVP this does NOT perform a real purchase yet.
  /// It queries StoreKit availability and product configuration and returns a user-facing message.
  Future<String?> tryPurchaseMonthlyWithApple() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (kIsWeb) {
        _error = 'StoreKit ist auf Web nicht verfügbar.';
        return _error;
      }

      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        _error = 'StoreKit ist aktuell nicht verfügbar (isAvailable=false).';
        return _error;
      }

      final response = await iap.queryProductDetails({appleProductIdMonthly});
      if (response.error != null) {
        _error = 'StoreKit Query Fehler: ${response.error}';
        return _error;
      }
      if (response.productDetails.isEmpty) {
        _error = 'StoreKit Produkt nicht gefunden: "$appleProductIdMonthly". TODO: App Store Connect Produkt anlegen + IDs matchen.';
        return _error;
      }

      // Intentionally not starting a purchase in this MVP step.
      return 'TODO: Apple Purchase aktivieren (StoreKit purchase). Produkt erkannt: ${response.productDetails.first.price}';
    } catch (e) {
      _error = 'StoreKit Fehler: $e';
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

