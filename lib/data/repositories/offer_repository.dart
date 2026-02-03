import '../models/offer.dart';
import '../services/offer_api.dart';

class OfferRepository {
  static Future<List<Offer>> getOffers({String? retailer, String? weekKey}) async {
    try {
      return await OfferApi.fetchOffers(retailer: retailer, weekKey: weekKey);
    } catch (e) {
      // Return empty list on error for graceful degradation
      return <Offer>[];
    }
  }

  /// Debug-only refresh; UI must check/validate secret
  static Future<Map<String, dynamic>> debugRefresh(String adminSecret) async {
    return OfferApi.refreshOffers(adminSecret: adminSecret);
  }
}