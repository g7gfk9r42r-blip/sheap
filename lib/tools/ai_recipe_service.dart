/// AIRecipeService (Dart)
/// Generiert Rezepte aus Angeboten mithilfe der OpenAI API.
/// 
/// Output-Format:
/// {
///   "title": "...",
///   "ingredients": [{"name": "...", "amount": "..."}],
///   "priceEstimate": 4.79,
///   "instructions": "...",
///   "source": "GPT",
///   "supermarket": "REWE"
/// }

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/offer.dart';

class AIRecipeService {
  final String apiKey;
  final String baseUrl;

  AIRecipeService({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
  });

  /// Generiert 30-50 Rezepte für einen Supermarkt basierend auf dessen Angeboten
  Future<List<Map<String, dynamic>>> generateRecipes({
    required String supermarket,
    required List<Offer> offers,
    int minRecipes = 30,
    int maxRecipes = 50,
  }) async {
    if (offers.isEmpty) {
      print('⚠️  No offers provided for $supermarket, skipping recipe generation');
      return [];
    }

    // Ziel: 30-50 Rezepte, generiere in Batches von 10-12
    final targetCount = (minRecipes + maxRecipes) ~/ 2; // ~40 recipes
    final batchSize = 12; // Recipes per API call
    final batches = (targetCount / batchSize).ceil();
    
    print('📊 Generating recipes for $supermarket: ${offers.length} offers → ~$targetCount recipes in $batches batches');

    final List<Map<String, dynamic>> allRecipes = [];
    
    // Erstelle detaillierte Angebots-Zusammenfassung für AI (ALLE Angebote)
    // Nutze möglichst viele Angebote (75-100%)
    final offerSummary = offers
        .map((offer) {
          final unitStr = offer.unit != null ? '/${offer.unit}' : '';
          return '${offer.title} (€${offer.price.toStringAsFixed(2)}$unitStr)';
        })
        .join(', ');

    // Generiere Rezepte in Batches
    for (int batch = 0; batch < batches; batch++) {
      try {
        print('   🔄 Batch ${batch + 1}/$batches...');
        final recipes = await _generateBatch(
          supermarket: supermarket,
          offerSummary: offerSummary,
          batchNumber: batch,
          totalBatches: batches,
          excludeTitles: allRecipes.map((r) => r['title'] as String).toList(),
        );
        
        allRecipes.addAll(recipes);
        print('   ✅ Generated ${recipes.length} recipes (total: ${allRecipes.length})');
        
        // Kurze Pause zwischen Batches um Rate Limits zu vermeiden
        if (batch < batches - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        print('   ❌ Batch ${batch + 1} failed: $e');
        // Continue with next batch
      }
    }

    // Begrenze auf maxRecipes
    if (allRecipes.length > maxRecipes) {
      return allRecipes.take(maxRecipes).toList();
    }

    // Wenn zu wenige, generiere mehr
    if (allRecipes.length < minRecipes) {
      print('⚠️  Only ${allRecipes.length} recipes generated, generating more...');
      final additional = await _generateBatch(
        supermarket: supermarket,
        offerSummary: offerSummary,
        batchNumber: batches,
        totalBatches: batches + 1,
        excludeTitles: allRecipes.map((r) => r['title'] as String).toList(),
      );
      allRecipes.addAll(additional);
    }

    return allRecipes.take(maxRecipes).toList();
  }

  /// Generiert einen Batch von Rezepten
  Future<List<Map<String, dynamic>>> _generateBatch({
    required String supermarket,
    required String offerSummary,
    required int batchNumber,
    required int totalBatches,
    required List<String> excludeTitles,
  }) async {
    final recipeCount = 12; // Recipes per batch
    
    // Erstelle detaillierte Angebotsliste für besseres Matching
    final offersList = offerSummary.split(', ').take(30).join(', ');
    
    final messages = [
      {
        'role': 'system',
        'content': '''Du bist eine KI, die aus Supermarkt-Angebotsdaten hochwertige, alltagstaugliche Rezepte generiert.

KRITISCHE REGELN:
1. Gib **ausschließlich gültiges JSON** zurück - kein Markdown, keine Code-Blöcke, keine Erklärungen
2. Erzeuge $recipeCount einzigartige, kreative Rezepte ohne Redundanz
3. Kombiniere Zutaten intelligent aus den Angeboten
4. IGNORIERE Basis-Zutaten: Salz, Pfeffer, Wasser, Standard-Gewürze, Öl, Butter, Mehl, Zucker (immer vorhanden)
5. **WICHTIG: Nutze 75-100% der verfügbaren Angebotsprodukte** - jedes Rezept soll möglichst viele verschiedene Angebote kombinieren
6. **Jedes Rezept MUSS ein "image_prompt" Feld enthalten** für die Bildgenerierung

JEDES REZEPT MUSS ENTHALTEN:
- "id": Eindeutige ID (z.B. "${supermarket.toLowerCase()}-1", "${supermarket.toLowerCase()}-2")
- "title": Kreativer, beschreibender Rezeptname
- "description": Kurze, appetitliche Beschreibung in 1-2 Sätzen
- "category": Eine von: "low_calorie", "high_protein", "balanced", "high_calorie", "vegetarian", "vegan"
- "supermarket": "$supermarket"
- "estimated_total_time_minutes": Zahl (15-60 Minuten)
- "portions": Zahl (typisch 2-4)
- "ingredients": Array von Objekten mit:
  - "name": Lebensmittelname (möglichst passend zu Angebotstitel)
  - "amount": z.B. "250 g", "1 Stück", "1 Packung"
  - "is_offer_product": true/false (true wenn aus Angeboten)
  - "offer_title_match": Originaltitel aus Angeboten oder bester Match
- "instructions": Array von Strings ["Schritt 1...", "Schritt 2..."]
- "nutrition_estimate": Objekt mit "kcal_per_portion", "protein_g", "carbs_g", "fat_g"
- "image_prompt": DALL·E/AI-Bildbeschreibung für realistische Food-Fotografie
- "tags": Array wie ["schnell", "familie", "mealprep", "low_budget"]

REZEPT-ANFORDERUNGEN:
- Gut nachkochbar für normale Familien
- Keine extrem exotischen Spezialzutaten (außer in Angeboten)
- Preisbewusst (möglichst viele Angebotsprodukte nutzen)
- Variation: verschiedene Kategorien (low_calorie, high_protein, balanced, etc.)
- Alltagstauglich (15-40 Min typisch)

AUSGABEFORMAT (EXAKTES JSON, kein Markdown):
[
  {
    "id": "${supermarket.toLowerCase()}-1",
    "title": "Knusprige Hähnchen-Bowl mit Ofengemüse",
    "description": "Ein gesundes, proteinreiches Gericht mit knusprigem Hähnchen und buntem Ofengemüse.",
    "category": "high_protein",
    "supermarket": "$supermarket",
    "estimated_total_time_minutes": 35,
    "portions": 2,
    "ingredients": [
      {
        "name": "Hähnchenbrust",
        "amount": "250 g",
        "is_offer_product": true,
        "offer_title_match": "Hähnchenbrustfilet"
      },
      {
        "name": "Kartoffeln",
        "amount": "300 g",
        "is_offer_product": true,
        "offer_title_match": "Kartoffeln"
      },
      {
        "name": "Paprika",
        "amount": "1 Stück",
        "is_offer_product": true,
        "offer_title_match": "Paprika"
      }
    ],
    "instructions": [
      "Ofen auf 200°C vorheizen.",
      "Hähnchenbrust in Streifen schneiden und würzen.",
      "Gemüse in Stücke schneiden und auf Backblech legen.",
      "Alles 25 Minuten im Ofen backen.",
      "Heiß servieren."
    ],
    "nutrition_estimate": {
      "kcal_per_portion": 600,
      "protein_g": 35,
      "carbs_g": 45,
      "fat_g": 20
    },
    "image_prompt": "Realistische Food-Fotografie einer knusprigen Hähnchen-Bowl mit buntem Ofengemüse, professionelle Beleuchtung, Appetit anregend",
    "tags": ["schnell", "high_protein", "familie", "low_budget"]
  }
]

WICHTIG:
- Achte darauf, dass ingredients[].offer_title_match wirklich zu den gelieferten Angeboten passt
- **Nutze 75-100% der verfügbaren Angebotsprodukte** - kombiniere viele verschiedene Angebote pro Rezept
- **Jedes Rezept MUSS ein detailliertes "image_prompt" Feld haben** für realistische Food-Fotografie
- Variiere die Rezepte stark: verschiedene Kategorien, verschiedene Zubereitungsarten
- Antworte NUR mit JSON, ohne Erklärungstext.'''
      },
      {
        'role': 'user',
        'content': '''Erzeuge $recipeCount einzigartige, alltagstaugliche Rezepte für $supermarket basierend auf diesen wöchentlichen Angeboten:

$offersList

${excludeTitles.isNotEmpty ? '\nWICHTIG: Erstelle KEINE Rezepte mit diesen Titeln (bereits generiert):\n${excludeTitles.join(", ")}\n' : ''}

KRITISCHE ANFORDERUNGEN:
- Nutze 75-100% der verfügbaren Angebotsprodukte in deinen Rezepten
- Jedes Rezept soll möglichst viele verschiedene Angebote kombinieren
- Jedes Rezept MUSS ein detailliertes "image_prompt" Feld enthalten
- Variiere die Kategorien stark: low_calorie, high_protein, balanced, high_calorie, vegetarian, vegan
- Stelle sicher, dass jedes Rezept einzigartig ist und kreativ verschiedene Angebotsprodukte nutzt'''
      }
    ];

    final response = await _callOpenAI(messages);
    final recipes = _parseRecipesFromAI(response, supermarket);
    
    return recipes;
  }

  /// Ruft die OpenAI API auf
  Future<String> _callOpenAI(List<Map<String, dynamic>> messages) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': messages,
      'temperature': 0.8, // Höhere Temperatur für mehr Kreativität
      'max_tokens': 6000, // Mehr Tokens für detaillierte Rezepte mit allen Feldern
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null) {
      throw Exception('No content in OpenAI response');
    }

    return content;
  }

  /// Parst Rezepte aus der AI-Antwort
  List<Map<String, dynamic>> _parseRecipesFromAI(String content, String supermarket) {
    try {
      // Versuche JSON zu extrahieren
      String jsonStr = content.trim();
      
      // Entferne Markdown-Code-Blöcke falls vorhanden (```json oder ```)
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        // Entferne erste Zeile (```json oder ```) und letzte Zeile (```)
        if (lines.length >= 2) {
          jsonStr = lines.sublist(1, lines.length - 1).join('\n').trim();
        }
      }
      
      // Entferne führende/abschließende Leerzeichen und Zeilenumbrüche
      jsonStr = jsonStr.trim();
      
      // Versuche als JSON-Objekt zu parsen (falls AI ein Objekt mit "recipes" Key zurückgibt)
      dynamic decoded = jsonDecode(jsonStr);
      
      List<dynamic> recipes;
      if (decoded is Map<String, dynamic>) {
        // Suche nach Array in verschiedenen möglichen Keys
        if (decoded.containsKey('recipes')) {
          recipes = decoded['recipes'] as List;
        } else if (decoded.containsKey('data')) {
          recipes = decoded['data'] as List;
        } else {
          // Versuche Array direkt zu finden
          final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonStr);
          if (arrayMatch != null) {
            recipes = jsonDecode(arrayMatch.group(0)!) as List;
          } else {
            throw Exception('No recipe array found in response');
          }
        }
      } else if (decoded is List) {
        recipes = decoded;
      } else {
        throw Exception('Invalid JSON format in response');
      }
      
      if (recipes.isEmpty) {
        throw Exception('Response is empty');
      }

      // Validiere und normalisiere Rezepte
      return recipes.asMap().entries.map((entry) {
        final index = entry.key;
        final recipe = entry.value as Map<String, dynamic>;
        
        // Stelle sicher, dass alle benötigten Felder vorhanden sind
        return {
          'id': recipe['id'] as String? ?? '${supermarket.toLowerCase()}-${index + 1}',
          'title': recipe['title'] as String? ?? 'Untitled Recipe',
          'description': recipe['description'] as String? ?? 'Ein leckeres Rezept aus aktuellen Angeboten.',
          'category': recipe['category'] as String? ?? 'balanced',
          'supermarket': supermarket,
          'estimated_total_time_minutes': (recipe['estimated_total_time_minutes'] as num?)?.toInt() ?? 30,
          'portions': (recipe['portions'] as num?)?.toInt() ?? 2,
          'ingredients': (recipe['ingredients'] as List?)
                  ?.map((i) {
                    if (i is Map) {
                      return {
                        'name': i['name'] as String? ?? i.toString(),
                        'amount': i['amount'] as String? ?? '',
                        'is_offer_product': i['is_offer_product'] as bool? ?? false,
                        'offer_title_match': i['offer_title_match'] as String? ?? '',
                      };
                    } else {
                      return {
                        'name': i.toString(),
                        'amount': '',
                        'is_offer_product': false,
                        'offer_title_match': '',
                      };
                    }
                  })
                  .toList() ??
              [],
          'instructions': (recipe['instructions'] as List?)
                  ?.map((i) => i.toString())
                  .toList() ??
              ['Anleitung folgt...'],
          'nutrition_estimate': recipe['nutrition_estimate'] as Map<String, dynamic>? ??
              {
                'kcal_per_portion': 500,
                'protein_g': 25,
                'carbs_g': 50,
                'fat_g': 15,
              },
          'image_prompt': recipe['image_prompt'] as String? ??
              'Realistische Food-Fotografie dieses Gerichts, professionelle Beleuchtung',
          'tags': (recipe['tags'] as List?)?.map((t) => t.toString()).toList() ?? ['einfach'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to parse AI response: $e\nContent: ${content.substring(0, content.length > 200 ? 200 : content.length)}...');
    }
  }
}
