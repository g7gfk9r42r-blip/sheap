import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import '../../utils/week.dart';

class RecipeApi {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static Future<List<Recipe>> fetchRecipes({String? retailer, String? weekKey}) async {
    final qp = <String, String>{};
    if (retailer != null && retailer.isNotEmpty) qp['retailer'] = retailer;
    qp['week'] = (weekKey != null && weekKey.isNotEmpty)
        ? weekKey
        : isoWeekKey(DateTime.now());

    final uri = Uri.parse('$baseUrl/recipes').replace(queryParameters: qp);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Recipes failed: ${res.statusCode} ${res.body}');
    }
    final data = json.decode(res.body);
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['recipes'] is List) {
      list = data['recipes'] as List;
    } else {
      list = const [];
    }
    return list.map<Recipe>((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
  }
}
