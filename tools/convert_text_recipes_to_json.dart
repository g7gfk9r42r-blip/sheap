#!/usr/bin/env dart
/// Konvertiert Text-Rezepte in JSON-Format
/// Überschreibt recipes_aldi_nord.json

import 'dart:io';
import 'dart:convert';

void main() {
  final recipesText = '''
1. Saftorangen-Joghurt-Bowl mit Walnüssen

Angebote: Saftorangen, LANDLIEBE Fruchtjoghurt, FARMER NATURALS Walnusskerne, Bio-Honig
Orangen filetieren, mit Landliebe-Joghurt in eine Schale geben. Walnusskerne grob hacken und darüberstreuen, mit etwas Bio-Honig toppen. Perfektes Frühstück oder Snack.

⸻

2. Braeburn-Apfel-Crumble im Glas

Angebote: Äpfel Braeburn, SWEET VALLEY Apfelmus, BISCOTTO Löffelbiskuits, Bio-Honig
Äpfel würfeln, kurz in der Pfanne mit etwas Honig anschwitzen. In Gläser füllen, Apfelmus darübergeben. Löffelbiskuits zerbröseln und als Crumble oben drauf. Kurz im Ofen überbacken.

⸻

3. Sonnentomaten-Mango-Salat mit Feta-Style

Angebote: Sonnentomaten lose, Mango, SALAKIS Schafskäse Natur
Tomaten und Mango würfeln, Salakis in Würfel bröseln. Mit Olivenöl, Zitronensaft, Salz & Pfeffer mischen. Super frischer, günstiger Salat.

⸻

4. Eisbergsalat-Cheese-Bowl mit Edelsalami

Angebote: Eisbergsalat, GUT DREI EICHEN Herzhafte Edelsalami, BERGADER Bergbauernkäse
Eisbergsalat fein schneiden, mit Salami-Streifen und Bergader-Käsewürfeln mischen. Ein Dressing aus Joghurt, Senf & Honig dazu. Ideal als schnelles Abendessen.

⸻

5. Mediterrane Pasta mit Gemüsesugo & Sonnentomaten

Angebote: GOURMET FINEST CUISINE Frische Pasta, ORO DI PARMA Gemüsesugo, Sonnentomaten
Frische Pasta kochen, Sugo erhitzen. Sonnentomaten in Scheiben schneiden, kurz mit zum Sugo geben. Alles mischen, mit etwas Bergader-Käse oder Salakis toppen.

⸻

6. Skyr-Protein-Breakfast mit Walnüssen & Honig

Angebote: ARLA Skyr Natur Cremig, FARMER NATURALS Walnusskerne, Bio-Honig
Skyr in eine Schale geben, Walnüsse grob hacken und darüberstreuen. Mit Honig süßen. Sehr hohes Protein, perfekt vor Schule/Training.

⸻

7. Landliebe-Apfel-Overnight-Oats

Angebote: LANDLIEBE Fruchtjoghurt, Äpfel Braeburn
Haferflocken mit Landliebe-Joghurt und etwas Milch mischen, Apfelwürfel unterheben. Über Nacht im Kühlschrank ziehen lassen. Morgens mit extra Apfelstücken toppen.

⸻

8. „Der Große Bauer" Dessert-Schicht im Glas

Angebote: BAUER Der Große Joghurt, SWEET VALLEY Apfelmus, BISCOTTO Löffelbiskuits
Löffelbiskuits zerbröseln, abwechselnd mit Joghurt und Apfelmus in Gläser schichten. Kurz kaltstellen – super simples Dessert für Gäste.

⸻

9. Ziegenfrischkäse-im-Speckmantel auf Salat

Angebote: GOURMET FINEST CUISINE Ziegenfrischkäse im Speckmantel, Eisbergsalat
Ziegenkäse laut Packung im Ofen backen. Eisbergsalat mit Mango-Würfeln und Sonnentomaten mischen. Warmen Ziegenkäse oben drauf – fertig ist der „Restaurant-Style" Teller.

⸻

10. Prosciutto-Panini mit Sonnentomaten

Angebote: Prosciutto Crudo Grande Riserva, Sonnentomaten, Kerrygold extra
Brötchen aufschneiden, mit Kerrygold bestreichen, Prosciutto und Tomatenscheiben hinein. Im Kontaktgrill oder in der Pfanne knusprig toasten.

⸻

11. Meraner-Schinken-Flammkuchen

Angebote: Meraner Schinken, GOURMET Frische Pasta (als Flammkuchenteig ersetzbar mit fertigem Teig), Landliebe Joghurt
Fertigen Flammkuchenteig (nicht im Prospekt, Standardartikel) mit Joghurt-Schmand-Mischung bestreichen, Meraner Schinken in Streifen draufgeben, mit Zwiebeln belegen und knusprig backen.

⸻

12. Lachsfilet aus dem Ofen mit Rahmspinat

Angebote: GOURMET Schottische Lachsfilets, IGLO Rahmspinat, Langkornreis (Standardware)
Lachs im Ofen mit Zitronensaft, Salz & Pfeffer garen. Rahmspinat erwärmen, mit Reis servieren. Klassisches „schnell & gesund" Gericht.

⸻

13. Lachs-Pasta mit Gemüsesugo

Angebote: GOURMET Schottische Lachsfilets, GOURMET Frische Pasta, ORO DI PARMA Gemüsesugo
Lachs würfeln und in der Pfanne anbraten, Sugo dazugeben. Mit gekochter frischer Pasta mischen. Optional etwas Skyr unterrühren für mehr Cremigkeit.

⸻

14. Mango-Salakis-Wraps

Angebote: Mango, SALAKIS Schafskäse, Eisbergsalat
Tortilla-Wraps (Standard) mit Salat, Mango-Streifen und zerbröseltem Salakis füllen. Mit Joghurt-Knoblauch-Sauce (aus Landliebe/Skyr) toppen. Ideal als Snack oder leichtes Abendessen.

⸻

15. Hähnchen-Brustfilet aus dem Ofen mit Mango-Salsa

Angebote: MEINE METZGEREI Hähnchen-Brustfilets, Mango, Sonnentomaten, Eisbergsalat
Hähnchenfilets würzen und im Ofen garen. Mango & Sonnentomaten klein schneiden, mit Limette, Salz, Pfeffer vermengen. Mit frischem Salat servieren.

⸻

16. Hähnchen-Minutenschnitzel mit Kartoffelsalat

Angebote: Hähnchen-Minutenschnitzel, DEVELEY Foodtrip-Saucen, DELIKATO Mayonnaise
Minutenschnitzel panieren/braten. Aus gekochten Kartoffeln, Mayonnaise, Gurken und Zwiebeln einen schnellen Kartoffelsalat machen. Mit einer besonderen Foodtrip-Sauce servieren.

⸻

17. Hähnchen-Hackfleisch-Bowl („Lean Protein Bowl")

Angebote: FAIR & GUT Hähnchen-Hackfleisch, Eisbergsalat, Sonnentomaten, OATLY Hafer-Barista (für cremige Sauce)
Hähnchenhack anbraten, mit Gewürzen abschmecken. Auf einem Bett aus Eisbergsalat & Tomaten servieren. Aus Oatly, Senf und Gewürzen ein cremiges Dressing machen.

⸻

18. Gemischtes Hackfleisch-Lasagne mit Gemüsesugo

Angebote: MEINE METZGEREI Gemischtes Hackfleisch, ORO DI PARMA Gemüsesugo, Landliebe Joghurt
Hackfleisch anbraten, mit Sugo köcheln. Mit Lasagneplatten schichten, oben eine Mischung aus Joghurt & Käse verteilen und backen.

⸻

19. Spießbraten aus dem Ofen mit Rahmspinat & Kartoffeln

Angebote: MEINE METZGEREI Spießbraten, IGLO Rahmspinat
Spießbraten im Bräter langsam garen. Mit Rahmspinat und Salzkartoffeln servieren – perfektes Sonntagsessen.

⸻

20. Sauerbraten mit Apfel-Rotkohl (Resteverwertung)

Angebote: FAIR & GUT Sauerbraten, Äpfel Braeburn
Sauerbraten nach Packungsangabe schmoren. Rotkohl (Standardartikel) mit Apfelwürfeln verfeinern. Ideal für den Wochenend-Familientisch.

⸻

21. Wildschweingulasch mit Spätzle

Angebote: GOURMET Wildschweingulasch
Gulasch erwärmen und kurz aufkochen lassen. Mit frischer Pasta oder Spätzle (Standard) servieren. Perfektes „Weihnachtsmarkt-Feeling" daheim.

⸻

22. BBQ-Marinierte Nackensteaks mit Ofenkartoffeln

Angebote: BBQ Marinierte Nackensteaks, DEVELEY Foodtrip-Saucen
Nackensteaks grillen oder braten. Kartoffeln im Ofen als Wedges backen. Mit einer der Foodtrip-Saucen servieren. Tipp: gleich mehrere Steaks machen und Reste am nächsten Tag kalt auf Brot essen.

⸻

23. Hähnchen-Schenkel mit Ofengemüse

Angebote: MEINE METZGEREI Hähnchen-Schenkel, Eisbergsalat (als Beilage), Saftorangen (für Marinade)
Hähnchenschenkel mit Orangensaft, Öl, Paprika & Knoblauch marinieren, im Ofen backen. Dazu Ofengemüse und ein kleiner Salat.

⸻

24. Entrecôte mit Mangosalat

Angebote: FAIR & GUT Entrecôte, Mango, Sonnentomaten
Entrecôte scharf anbraten, kurz ruhen lassen. Dazu Mango-Tomaten-Salat mit Limette und Olivenöl servieren – „Steakhouse-Feeling" zum Angebotspreis.

⸻

25. Puten-Schnitzel „Wiener Art" mit Gurkensalat

Angebote: MEINE METZGEREI Puten-Schnitzel „Wiener Art", DEVELEY Mayonnaise / Schlemmersauce
Puten-Schnitzel ausbraten, mit einem frischen Gurkensalat (Gurke, Essig, Öl, Dill) servieren. Schlemmersauce als Dip dazu.

⸻

26. Junge Ente mit Orangen-Rotkohl

Angebote: JACK'S FARM Junge Ente, Saftorangen, Äpfel Braeburn
Ente im Ofen braten. Rotkohl mit Orangenfilets und Apfelwürfeln verfeinern. Klassisches Festtagsgericht mit Prospekt-Zutaten.

⸻

27. Backfisch-Buns mit Rahmspinat

Angebote: IGLO Backfisch/Fischstäbchen, IGLO Rahmspinat
Backfisch im Ofen backen, in Burgerbrötchen mit etwas Rahmspinat und Salat servieren. Kids-taugliches Fast-Food in „besser".

⸻

28. Garnelen-Pasta in Knoblauch-Zitronen-Sauce

Angebote: GOLDEN SEAFOOD Garnelen, GOURMET Frische Pasta
Garnelen mit Knoblauch und Zitrone in der Pfanne braten, mit etwas Oatly oder Skyr cremig machen. Mit frischer Pasta servieren.

⸻

29. Nordsee-Backfisch mit Kartoffel-Spinat-Püree

Angebote: NORDSEE Backfisch, IGLO Rahmspinat
Kartoffelpüree zubereiten, Rahmspinat unterheben. Backfisch knusprig ausbacken und dazu servieren.

⸻

30. BÜRGER Maultaschen-Pfanne

Angebote: BÜRGER Maultaschen, Sonnentomaten, Eisbergsalat (als Beilage)
Maultaschen in Scheiben schneiden, in der Pfanne anbraten, mit Zwiebeln und etwas Gemüsesugo schwenken. Dazu Salat servieren.

⸻

31. „Wintersalat Deluxe" mit Ziegenfrischkäse & Walnüssen

Angebote: Ziegenfrischkäse im Speckmantel, Eisbergsalat, Sonnentomaten, Walnusskerne
Ziegenfrischkäse backen. Salat, Tomaten und Walnüsse anrichten, mit Honig-Senf-Dressing toppen, warmen Ziegenkäse oben drauf.

⸻

32. Panettone-French-Toast

Angebote: GOURMET Panettone, Bio-Honig
Panettone in Scheiben schneiden, in Ei-Milch-Mischung wenden und in der Pfanne ausbacken. Mit Honig und Orangenfilets servieren.

⸻

33. Schokolierte Früchte-Platte

Angebote: GOURMET Schokolierte Früchte, Mango, Saftorangen, Äpfel
Frische Früchte auf einer Platte anrichten, mit schokolierten Früchten ergänzen. Perfekter Snack für Filmabend oder Gäste.

⸻

34. Winterlicher Pudding-Traum

Angebote: DR. OETKER Pudding/Dessert-Soße, ZUM DORFKRUG Pudding/Grütze
Pudding nach Packung zubereiten, mit Grütze schichten. Dessert-Soße drüber – schnell, günstig und „instagrammable".

⸻

35. High-Protein-Mousse-Schichtdessert

Angebote: MILSANI High-Protein-Mousse, FARMER Walnusskerne, Bio-Honig
Mousse in Gläser füllen, Walnüsse und etwas Honig darauf. Fertig ist ein proteinreicher Nachtisch.

⸻

36. „Der schnelle Tiramisu-Fake"

Angebote: BISCOTTO Löffelbiskuits, Landliebe Joghurt, Bio-Honig
Löffelbiskuits in Kaffee (Standard) tunken, mit Joghurt schichten. Mit Kakao bestäuben. Leichtes „Tiramisu ohne Mascarpone".

⸻

37. Viennetta-Dessert mit Orangenfilets

Angebote: LANGNESE Viennetta Vanilla, Saftorangen
Viennetta in Scheiben schneiden, mit frischen Orangenfilets toppen. Einfacher Weg, ein günstiges TK-Dessert „aufzuwerten".

⸻

38. Magnum-Eis-Affogato

Angebote: LANGNESE Magnum-Stieleis, MÖVENPICK Mahlkaffee oder JACOBS® Kaffeekapseln
Espresso zubereiten, eine Magnum-Stange in ein Glas stellen und den Espresso darüber gießen. Ultra simples, aber krasses Dessert.

⸻

39. Müsliriegel-Joghurt-Bowl

Angebote: CORNY Müsliriegel, BAUER/ LANDLIEBE Joghurt, Äpfel oder Mango
Müsliriegel zerbröseln, über eine Joghurt-Basis streuen. Mit Obstwürfeln toppen. Perfekt als Snack „to go".

⸻

40. Chips & Dip Abendplatte

Angebote: SUN SNACKS Riffel-Chips, FUNNY-FRISCH Chipsfrisch, LORENZ Saltletts, KING'S CROWN Oliven, DEVELEY Foodtrip-Saucen
Verschiedene Snacks auf einer Platte arrangieren, Oliven in Schälchen dazu, Foodtrip-Saucen als Dip. Ideal für Spiele- oder Fußballabend.

⸻

41. Glühwein & Apfel-Punsch

Angebote: Glühwein, RIO D'ORO naturtrüber Apfeldirektsaft, Saftorangen
Glühwein erhitzen (nicht kochen). Für den alkoholfreien Punsch Apfelsaft mit Orangenscheiben, Zimt und Nelken erwärmen. Zwei Varianten für Gäste in einem Topf-Setup.

⸻

42. Espresso-Martini-Style Drink (für Erwachsene)

Angebote: MÖVENPICK Mahlkaffee, JAMESON Irish Whiskey (oder andere Spirituosen aus dem Prospekt)
Espresso kochen, mit Whiskey, etwas Zucker und Eis shaken. In ein Glas abseihen – ideal für ein „Feierabend-Special".

⸻

43. Frühstücks-Toast mit Kerrygold & Bergbauernkäse

Angebote: KERRYGOLD extra, BERGADER Bergbauernkäse
Toast mit Kerrygold bestreichen, Käse drauf, kurz überbacken. Kann mit Tomatenscheiben und Eisbergsalat ergänzt werden.

⸻

44. „Studenten-One-Pot" mit Hack & Pasta

Angebote: Gemischtes Hack, ORO DI PARMA Gemüsesugo, GOURMET Frische Pasta
Hack anbraten, Sugo dazu, Pasta direkt mitkochen (ggf. etwas Wasser hinzufügen). Ein Topf, wenig Abwasch, großes Sättigungslevel.

⸻

45. Homann-Hering-Kartoffel-Teller

Angebote: HOMANN Hering in Marinade, IGLO Rahmspinat (optional), Kartoffeln (Standard)
Kartoffeln kochen, Hering dazu servieren. Wer mag, packt etwas warmen Rahmspinat auf den Teller – „Norddeutsch light".

⸻

46. Fischfrikadellen-Burger

Angebote: NORDSEE Fischfrikadellen, Eisbergsalat, DEVELEY Foodtrip-Saucen
Burgerbrötchen mit Salat und Fischfrikadelle belegen, mit einer Foodtrip-Sauce toppen. Schnell, praktisch, Street-Food-Style.

⸻

47. Süßer Joghurt-Honig-Dip zu Obstplatte

Angebote: Landliebe oder Bauer Joghurt, Bio-Honig, Saftorangen, Äpfel, Mango
Joghurt mit Honig verrühren. Obst schneiden, alles auf einer Platte anrichten. Perfekt als gesunde Alternative zu Schokolade & Keksen.

⸻

48. Blätterteig-Minis-Platte (Fingerfood)

Angebote: GOURMET Blätterteig-Minis
Blätterteig-Minis nach Packung backen, auf einer Platte anrichten. Optional mit einem schnellen Dip aus Skyr, Kräutern und Zitrone servieren.

⸻

49. Winterliches Brotzeitbrett

Angebote: Herzhafte Edelsalami, Bergbauern-Käse, GÜLDENHOF Geflügel-Fleischwurst, SALAKIS, schokolierte Früchte, Panettone
Alles in Scheiben schneiden und auf einem großen Brett anrichten. Ideal, wenn Freunde spontan vorbeikommen und man „aus Angeboten" ein Brett zaubern will.

⸻

50. „Wohlfühl-Winter" Suppe mit Hähnchen & Gemüse

Angebote: Hähnchen-Brustfilets, Eisbergsalat (als knackige Einlage), Sonnentomaten, ORO DI PARMA Gemüsesugo
Hähnchenwürfel anbraten, mit Gemüsesugo und Brühe aufgießen, Gemüse nach Wahl dazugeben. Kurz vor dem Servieren etwas fein geschnittenen Eisbergsalat für Crunch einrühren.
''';

  final recipes = _parseRecipes(recipesText);
  final json = _convertToJson(recipes);
  
  final outputFile = File('assets/recipes/recipes_aldi_nord.json');
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(json),
  );
  
  print('✅ ${recipes.length} Rezepte gespeichert in ${outputFile.path}');
}

List<Map<String, dynamic>> _parseRecipes(String text) {
  final recipes = <Map<String, dynamic>>[];
  final sections = text.split('⸻');
  
  for (final section in sections) {
    final lines = section.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) continue;
    
    // Extrahiere Nummer und Titel
    final firstLine = lines[0].trim();
    final titleMatch = RegExp(r'^\d+\.\s*(.+)$').firstMatch(firstLine);
    if (titleMatch == null) continue;
    
    final title = titleMatch.group(1)!.trim();
    
    // Finde Angebote-Zeile
    String? offersLine;
    String? description;
    int descriptionStart = 1;
    
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].startsWith('Angebote:')) {
        offersLine = lines[i].substring('Angebote:'.length).trim();
        descriptionStart = i + 1;
        break;
      }
    }
    
    // Rest ist Beschreibung/Anleitung
    description = lines.sublist(descriptionStart).join(' ').trim();
    
    if (offersLine == null || description.isEmpty) continue;
    
    // Parse Angebote
    final offerNames = offersLine.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    
    // Erstelle Ingredients-Liste
    final ingredients = <Map<String, dynamic>>[];
    for (final offer in offerNames) {
      // Extrahiere Produktname (entferne Markennamen, behalte Produktname)
      String finalName = offer;
      
      // Liste bekannter Markennamen (ohne Umlaute in Regex)
      final brands = [
        'LANDLIEBE', 'FARMER NATURALS', 'SWEET VALLEY', 'BISCOTTO', 'SALAKIS',
        'GUT DREI EICHEN', 'BERGADER', 'GOURMET FINEST CUISINE', 'ORO DI PARMA',
        'ARLA', 'BAUER', 'KERRYGOLD', 'MEINE METZGEREI', 'FAIR & GUT', 'IGLO',
        'GOLDEN SEAFOOD', 'NORDSEE', 'BÜRGER', 'GÜLDENHOF', 'DEVELEY', 'DELIKATO',
        'OATLY', 'JACK\'S FARM', 'MILSANI', 'LANGNESE', 'MÖVENPICK', 'JACOBS',
        'CORNY', 'SUN SNACKS', 'FUNNY-FRISCH', 'LORENZ', 'KING\'S CROWN',
        'RIO D\'ORO', 'JAMESON', 'DR. OETKER', 'ZUM DORFKRUG', 'HOMANN',
        'GOURMET', 'FAIR', 'GUT', 'DER GROSSE', 'JACK', 'FARM',
      ];
      
      // Entferne Markennamen am Anfang (case-insensitive)
      final offerUpper = offer.toUpperCase();
      for (final brand in brands) {
        if (offerUpper.startsWith(brand)) {
          finalName = offer.substring(brand.length).trim();
          break;
        }
      }
      
      // Falls nach Markenentfernung leer oder zu kurz, verwende Original
      if (finalName.isEmpty || finalName.length < 3) {
        finalName = offer;
      }
      
      ingredients.add({
        'name': finalName,
        'amount': '', // Wird später ergänzt
        'is_offer_product': true,
        'offer_title_match': offer,
      });
    }
    
    // Bestimme Kategorie basierend auf Titel/Beschreibung
    final category = _determineCategory(title, description);
    
    // Bestimme Tags
    final tags = _determineTags(title, description);
    
    // Schätze Zeit und Portionen
    final timeMinutes = _estimateTime(description);
    final portions = _estimatePortions(description);
    
    // Erstelle Instructions aus Beschreibung
    final instructions = _extractInstructions(description);
    
    recipes.add({
      'id': 'aldi_nord-${recipes.length + 1}',
      'title': title,
      'description': description,
      'category': category,
      'supermarket': 'ALDI_NORD',
      'estimated_total_time_minutes': timeMinutes,
      'portions': portions,
      'ingredients': ingredients,
      'instructions': instructions,
      'nutrition_estimate': _estimateNutrition(category, ingredients),
      'image_prompt': 'Realistische Food-Fotografie von $title, professionelle Beleuchtung, appetitlich präsentiert',
      'tags': tags,
    });
  }
  
  return recipes;
}

String _determineCategory(String title, String description) {
  final lower = (title + ' ' + description).toLowerCase();
  
  if (lower.contains(RegExp(r'\b(protein|hähnchen|lachs|fleisch|hack|steak|ente|puten|schnitzel)\b'))) {
    return 'high_protein';
  }
  if (lower.contains(RegExp(r'\b(salat|bowl|gemüse|tomaten|mango|orange|apfel)\b'))) {
    return 'low_calorie';
  }
  if (lower.contains(RegExp(r'\b(dessert|pudding|tiramisu|mousse|eis|schokolade|panettone)\b'))) {
    return 'high_calorie';
  }
  if (lower.contains(RegExp(r'\b(vegetarisch|vegan|joghurt|käse|salat)\b')) && 
      !lower.contains(RegExp(r'\b(fleisch|hähnchen|lachs|hack|salami|schinken)\b'))) {
    return 'vegetarian';
  }
  return 'balanced';
}

List<String> _determineTags(String title, String description) {
  final lower = (title + ' ' + description).toLowerCase();
  final tags = <String>[];
  
  if (lower.contains(RegExp(r'\b(schnell|minuten|kurz|rapid|quick)\b'))) {
    tags.add('schnell');
  }
  if (lower.contains(RegExp(r'\b(familie|familien|kinder|kids)\b'))) {
    tags.add('familie');
  }
  if (lower.contains(RegExp(r'\b(budget|günstig|preiswert|sparen)\b'))) {
    tags.add('low_budget');
  }
  if (lower.contains(RegExp(r'\b(frühstück|breakfast|overnight|müsli)\b'))) {
    tags.add('frühstück');
  }
  if (lower.contains(RegExp(r'\b(dessert|nachtisch|süß|sweet)\b'))) {
    tags.add('dessert');
  }
  if (lower.contains(RegExp(r'\b(protein|high.protein)\b'))) {
    tags.add('high_protein');
  }
  if (lower.contains(RegExp(r'\b(one.pot|ein.topf|pfanne)\b'))) {
    tags.add('one_pot');
  }
  
  if (tags.isEmpty) tags.add('einfach');
  return tags;
}

int _estimateTime(String description) {
  final lower = description.toLowerCase();
  
  if (lower.contains(RegExp(r'\b(über.nacht|overnight)\b'))) return 480; // 8 Stunden
  if (lower.contains(RegExp(r'\b(langsam|schmoren|bräter)\b'))) return 120; // 2 Stunden
  if (lower.contains(RegExp(r'\b(backen|ofen|garen)\b'))) return 45;
  if (lower.contains(RegExp(r'\b(schnell|kurz|minuten)\b'))) return 15;
  
  return 30; // Default
}

int _estimatePortions(String description) {
  final lower = description.toLowerCase();
  
  if (lower.contains(RegExp(r'\b(familie|familien|gäste|mehrere)\b'))) return 4;
  if (lower.contains(RegExp(r'\b(bowl|glas|teller|portion)\b'))) return 2;
  
  return 2; // Default
}

List<String> _extractInstructions(String description) {
  // Teile Beschreibung in Sätze auf
  final sentences = description
      .split(RegExp(r'[.!?]\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s.length > 5)
      .toList();
  
  if (sentences.isEmpty) {
    return [description];
  }
  
  return sentences;
}

Map<String, dynamic> _estimateNutrition(String category, List<Map<String, dynamic>> ingredients) {
  int baseKcal = 400;
  int baseProtein = 20;
  int baseCarbs = 50;
  int baseFat = 15;
  
  // Passe basierend auf Kategorie an
  switch (category) {
    case 'high_protein':
      baseKcal = 500;
      baseProtein = 40;
      baseCarbs = 30;
      baseFat = 20;
      break;
    case 'low_calorie':
      baseKcal = 250;
      baseProtein = 15;
      baseCarbs = 30;
      baseFat = 8;
      break;
    case 'high_calorie':
      baseKcal = 600;
      baseProtein = 10;
      baseCarbs = 80;
      baseFat = 25;
      break;
  }
  
  // Passe basierend auf Zutaten an
  final ingredientNames = ingredients.map((i) => i['name'].toString().toLowerCase()).join(' ');
  
  if (ingredientNames.contains(RegExp(r'\b(hähnchen|lachs|fleisch|hack|protein)\b'))) {
    baseProtein += 10;
  }
  if (ingredientNames.contains(RegExp(r'\b(pasta|reis|kartoffel|brot)\b'))) {
    baseCarbs += 20;
  }
  if (ingredientNames.contains(RegExp(r'\b(käse|butter|öl|creme)\b'))) {
    baseFat += 10;
  }
  
  return {
    'kcal_per_portion': baseKcal,
    'protein_g': baseProtein,
    'carbs_g': baseCarbs,
    'fat_g': baseFat,
  };
}

List<Map<String, dynamic>> _convertToJson(List<Map<String, dynamic>> recipes) {
  return recipes;
}

