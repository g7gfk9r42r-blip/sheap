import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/offer.dart';
import '../../utils/week.dart';

class OfferApi {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Fetch offers for a given retailer and optional week
  static Future<List<Offer>> fetchOffers({
    String? retailer,
    String? weekKey,
  }) async {
    final qp = <String, String>{};
    if (retailer != null && retailer.isNotEmpty) qp['retailer'] = retailer;
    qp['week'] = (weekKey != null && weekKey.isNotEmpty)
        ? weekKey
        : isoWeekKey(DateTime.now());

    final uri = Uri.parse('$baseUrl/offers').replace(queryParameters: qp);
    final res = await http.get(uri);
    
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch offers: ${res.statusCode} ${res.body}');
    }

    final data = json.decode(res.body);
    final List list;
    
    if (data is List) {
      list = data;
    } else if (data is Map && data['offers'] is List) {
      list = data['offers'] as List;
    } else {
      list = const [];
    }

    return list
        .map<Offer>((e) => Offer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Refresh offers for admin (requires secret)
  static Future<Map<String, dynamic>> refreshOffers({
    required String adminSecret,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/offers/refresh');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'adminSecret': adminSecret}),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Failed to refresh offers: ${res.statusCode} ${res.body}',
      );
    }

    return json.decode(res.body) as Map<String, dynamic>;
  }
}
